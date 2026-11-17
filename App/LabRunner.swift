import CoreSpotlight
import FoundationModels
import os
import UniformTypeIdentifiers
import UIKit
import Vision

@Generable
struct TaskDraft {
    @Guide(description: "やることの短いタイトル") var title: String
    @Guide(description: "明示された期限の表記。期限がない場合は空文字") var deadline: String
    @Guide(description: "明示された相手。相手がいない場合は空文字") var recipient: String
    @Guide(description: "急ぎだと明示されたか") var urgent: Bool
}

@Generable
struct ContentTags {
    @Guide(description: "Most important topics", .maximumCount(3)) let topics: [String]
    @Guide(description: "Objects mentioned in the text", .maximumCount(3)) let objects: [String]
    @Guide(description: "Actions taking place", .maximumCount(3)) let actions: [String]
    @Guide(description: "Emotions expressed in the text", .maximumCount(3)) let emotions: [String]
}

@Generable
enum TicketCategory {
    case bug
    case featureRequest
    case question

    var label: String {
        switch self {
        case .bug: "不具合"
        case .featureRequest: "機能要望"
        case .question: "質問"
        }
    }
}

struct RoomDirectory: Tool {
    let name = "lookUpRoom"
    let description = "Look up an example campus room by its Japanese name and return its actual hours and access requirements."

    @Generable
    struct Arguments {
        @Guide(description: "施設名。工作室、録音室、または展示室") var room: String
    }

    func call(arguments: Arguments) async throws -> String {
        switch arguments.room.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "工作室": "平日 10:00〜17:30。学生証と利用講習の受講が必要です。"
        case "録音室": "火曜・木曜 13:00〜18:00。事前予約が必要です。"
        case "展示室": "月曜〜土曜 09:00〜16:00。入室手続きは不要です。"
        default: "該当なし。登録施設は工作室、録音室、展示室です。"
        }
    }
}

final class ProfileSettings: Sendable {
    let brief = OSAllocatedUnfairLock(initialState: true)
}

@available(iOS 27, *)
struct LabProfile: LanguageModelSession.DynamicProfile {
    let settings: ProfileSettings

    var body: some DynamicProfile {
        if settings.brief.withLock({ $0 }) {
            Profile {
                Instructions { "日本語で一文だけで回答してください。" }
            }
            .maximumResponseTokens(100)
        } else {
            Profile {
                Instructions { "日本語で初心者向けに、理由と具体例を箇条書きで説明してください。" }
            }
            .maximumResponseTokens(400)
        }
    }
}

@MainActor
@Observable
final class LabRunner {
    var result = ""
    var trace: [String] = []
    var history: [Turn] = []
    var error: String?
    private(set) var running = false
    private var task: Task<Void, Never>?
    private var conversation: LanguageModelSession?
    private var profileSettings: ProfileSettings?
    private var savedTranscript: Transcript?

    struct Turn: Identifiable {
        let id = UUID()
        let prompt: String
        let response: String
    }

    func run(_ experiment: Experiment, text: String, image: UIImage?, brief: Bool) {
        guard !running else { return }
        result = ""
        error = nil
        trace = []
        running = true
        task = Task {
            defer {
                running = false
                task = nil
            }
            do {
                try await perform(experiment, text: text, image: image, brief: brief)
                try Task.checkCancellation()
                if experiment.keepsHistory {
                    savedTranscript = conversation?.transcript
                    history.append(Turn(prompt: text, response: result))
                    result = ""
                }
            } catch {
                if !Task.isCancelled {
                    self.error = error.localizedDescription
                }
                // Rebuild the session from completed turns after an interrupted request.
                conversation = nil
                profileSettings = nil
            }
        }
    }

    func cancel() { task?.cancel() }

    func reset() {
        guard !running else { return }
        history = []
        savedTranscript = nil
        conversation = nil
        profileSettings = nil
        trace = []
        result = ""
        error = nil
    }

    private func perform(_ experiment: Experiment, text: String, image: UIImage?, brief: Bool) async throws {
        switch experiment {
        case .generate:
            result = try await answer("ユーザーの指示に従い、日本語で書いてください。", text)
        case .summarize:
            result = try await answer("与えられた本文を日本語で3項目以内に要約。本文にない事実は加えないでください。", text)
        case .rewrite:
            result = try await answer("本文を意味を保って丁寧な日本語に書き換え、書き換えた文だけ返してください。", text)
        case .classify:
            let session = LanguageModelSession(instructions: "問い合わせを不具合、機能要望、質問のいずれかに分類してください。")
            let response = try await session.respond(to: text, generating: TicketCategory.self)
            result = response.content.label
        case .tagging:
            let session = LanguageModelSession(model: SystemLanguageModel(useCase: .contentTagging))
            let tags = try await session.respond(to: text, generating: ContentTags.self).content
            result = [("話題", tags.topics), ("物", tags.objects), ("行動", tags.actions), ("感情", tags.emotions)]
                .map { label, values in
                    "\(label)  \(values.isEmpty ? "—" : values.joined(separator: " · "))"
                }
                .joined(separator: "\n")
        case .structured:
            let session = extractionSession()
            let value = try await session.respond(to: text, generating: TaskDraft.self).content
            result = format(title: value.title, deadline: value.deadline, recipient: value.recipient, urgent: value.urgent)
        case .stream:
            for try await snapshot in LanguageModelSession().streamResponse(to: text) {
                result = snapshot.content
            }
        case .streamStructured:
            for try await snapshot in extractionSession().streamResponse(to: text, generating: TaskDraft.self) {
                let value = snapshot.content
                result = format(title: value.title, deadline: value.deadline, recipient: value.recipient, urgent: value.urgent)
            }
        case .chat:
            let session = conversation ?? savedTranscript.map { LanguageModelSession(transcript: $0) }
                ?? LanguageModelSession(instructions: "日本語で簡潔に会話してください。")
            conversation = session
            result = try await session.respond(to: text).content
        case .tools:
            let session = LanguageModelSession(tools: [RoomDirectory()], instructions: """
                必ず lookUpRoom で施設を調べ、取得した情報だけを使って日本語で答えてください。
                """)
            defer { showTools(in: session) }
            result = try await session.respond(to: text).content
        case .spotlight:
            #if !targetEnvironment(simulator)
            if #available(iOS 27, *) {
                try await indexSamples()
                let source = CoreSpotlightSource(fetchAttributes: [.title, .contentDescription, .textContent])
                let tool = SpotlightSearchTool(configuration: .init(sources: [.coreSpotlight(source)]))
                let session = LanguageModelSession(tools: [tool], instructions: """
                    必ず Spotlight で資料を検索し、見つかった内容だけをもとに日本語で回答してください。
                    """)
                defer { showTools(in: session) }
                result = try await session.respond(to: text).content
            }
            #endif
        case .tokens:
            if #available(iOS 26.4, *) {
                let model = SystemLanguageModel.default
                let count = try await model.tokenCount(for: Prompt(text))
                result = "入力  \(count.formatted()) トークン\n上限  \(model.contextSize.formatted()) トークン\n\n上限には指示、履歴、出力なども含まれます。"
            }
        case .profiles:
            if #available(iOS 27, *) {
                let settings = profileSettings ?? ProfileSettings()
                settings.brief.withLock { $0 = brief }
                profileSettings = settings
                let session = conversation ?? LanguageModelSession(
                    profile: LabProfile(settings: settings),
                    history: savedTranscript?.filter { entry in
                        if case .instructions = entry { return false }
                        return true
                    } ?? []
                )
                conversation = session
                result = try await session.respond(to: text).content
            }
        case .vision, .ocr, .barcode:
            if #available(iOS 27, *), let image {
                let tools: [any Tool]
                #if targetEnvironment(simulator)
                // The Vision tool overlay is only shipped in the device SDK.
                tools = []
                #else
                tools = switch experiment {
                case .ocr: [OCRTool()]
                case .barcode: [BarcodeReaderTool()]
                default: []
                }
                #endif
                let session = LanguageModelSession(tools: tools)
                defer { showTools(in: session) }
                result = try await session.respond {
                    text
                    Attachment(image).label("demoImage")
                }.content
            }
        }
    }

    private func indexSamples() async throws {
        let samples = [
            ("expo", "ロボット展示会 受付案内", "11月25日の12:30から、北キャンパスの講堂入口で受付します。"),
            ("studio", "工作室 見学会", "12月3日の14:00に、西キャンパスの実習棟入口へ集合します。"),
            ("library", "図書館 特別開館", "試験期間中は平日20:30まで利用できます。")
        ]
        let items = samples.map { id, title, body in
            let attributes = CSSearchableItemAttributeSet(contentType: .text)
            attributes.title = title
            attributes.contentDescription = body
            attributes.textContent = body
            return CSSearchableItem(uniqueIdentifier: id, domainIdentifier: "lab-samples", attributeSet: attributes)
        }
        try await CSSearchableIndex.default().indexSearchableItems(items)
    }

    private func answer(_ instructions: String, _ input: String) async throws -> String {
        try await LanguageModelSession(instructions: instructions).respond(to: input).content
    }

    private func extractionSession() -> LanguageModelSession {
        LanguageModelSession(instructions: "入力に書かれたタスクを抽出してください。明示されていない情報は推測しないでください。")
    }

    private func format(title: String?, deadline: String?, recipient: String?, urgent: Bool?) -> String {
        func display(_ value: String?) -> String {
            guard let value, !value.isEmpty else { return "—" }
            return value
        }
        let urgency = urgent.map { $0 ? "はい" : "いいえ" } ?? "—"
        return [
            "タスク  \(display(title))",
            "期限  \(display(deadline))",
            "相手  \(display(recipient))",
            "急ぎ  \(urgency)"
        ].joined(separator: "\n")
    }

    private func showTools(in session: LanguageModelSession) {
        trace = session.transcript.flatMap { entry -> [String] in
            switch entry {
            case .toolCalls(let calls):
                calls.map { "\($0.toolName)  \($0.arguments.jsonString)" }
            case .toolOutput(let output):
                ["\(output.toolName) の結果\n" + output.segments.compactMap { segment in
                    guard case .text(let text) = segment else { return nil }
                    return text.content
                }.joined(separator: "\n")]
            default:
                []
            }
        }
    }
}
