import CoreImage
import CoreImage.CIFilterBuiltins
import FoundationModels
import PhotosUI
import SwiftUI

@main
struct OnDeviceAILab: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                CatalogView()
            }
            .tint(.indigo)
        }
    }
}

@MainActor
private struct CatalogView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var availability = SystemLanguageModel.default.availability

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: availability == .available ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .foregroundStyle(availability == .available ? .green : .orange)
                        .font(.title2)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(statusMessage(availability)).font(.headline)
                        Text("Apple Intelligence · オンデバイス")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        availability = SystemLanguageModel.default.availability
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("モデルの状態を更新")
                }
            }
            ForEach(Experiment.sections, id: \.0) { title, experiments in
                Section(title) {
                    ForEach(experiments) { experiment in
                        NavigationLink {
                            ExperimentView(experiment: experiment)
                        } label: {
                            Label {
                                HStack {
                                    Text(experiment.rawValue)
                                    if let version = experiment.minimum {
                                        Spacer()
                                        Text(version)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } icon: {
                                Image(systemName: experiment.symbol)
                                    .foregroundStyle(.indigo)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("オンデバイスAIラボ")
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                availability = SystemLanguageModel.default.availability
            }
        }
    }
}

@MainActor
private struct ExperimentView: View {
    let experiment: Experiment
    @Environment(\.scenePhase) private var scenePhase
    @State private var runner = LabRunner()
    @State private var text: String
    @State private var brief = true
    @State private var modelAvailability = SystemLanguageModel.default.availability
    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var loadingImage = false
    @State private var photoError: String?

    init(experiment: Experiment) {
        self.experiment = experiment
        _text = State(initialValue: experiment.sample)
        _image = State(initialValue: experiment.usesImage ? DemoFlyer.make() : nil)
    }

    var body: some View {
        Form {
            Section {
                Text(experiment.detail)
                    .foregroundStyle(.secondary)
                if !experiment.supportedByOS, let version = experiment.minimum {
                    Label("\(version) 以降が必要です", systemImage: "info.circle")
                } else if experiment.requiresPhysicalDevice {
                    Label("この実験にはiPhone実機が必要です", systemImage: "iphone")
                } else if modelAvailability != .available {
                    Label(statusMessage(modelAvailability), systemImage: "exclamationmark.circle")
                }
            }

            if experiment.usesImage {
                Section("入力画像") {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("モデルに渡す画像")
                    }
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("写真を選ぶ", systemImage: "photo.on.rectangle")
                    }
                    Button("サンプル画像に戻す") {
                        pickerItem = nil
                        loadingImage = false
                        photoError = nil
                        image = DemoFlyer.make()
                    }
                    if loadingImage { ProgressView("画像を読み込み中") }
                    if let photoError { Text(photoError).foregroundStyle(.red) }
                }
                .disabled(runner.running || !experiment.supportedByOS)
            }

            if experiment.keepsHistory {
                Section("会話履歴") {
                    if runner.history.isEmpty {
                        Text("まだ会話がありません").foregroundStyle(.secondary)
                    }
                    ForEach(runner.history) { turn in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(turn.prompt).font(.subheadline).foregroundStyle(.secondary)
                            Text(turn.response).textSelection(.enabled)
                        }
                    }
                    if !runner.history.isEmpty {
                        Button("会話をリセット", role: .destructive) { runner.reset() }
                            .disabled(runner.running)
                    }
                }
            }

            Section("入力") {
                if experiment == .profiles {
                    Picker("応答の指示", selection: $brief) {
                        Text("一文で回答").tag(true)
                        Text("例付きの箇条書き").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .disabled(runner.running)
                }
                TextEditor(text: $text)
                    .frame(minHeight: 100)
                    .accessibilityLabel("入力テキスト")
                    .disabled(runner.running)
                Button("サンプル入力") { text = experiment.sample }
                    .disabled(runner.running)
                if experiment == .chat {
                    Button("前の発言について聞く") { text = "私のロボットの名前は何でしたか？" }
                        .disabled(runner.running)
                }
                if runner.running {
                    Button("停止", role: .destructive) { runner.cancel() }
                } else {
                    Button {
                        runner.run(experiment, text: text, image: image, brief: brief)
                    } label: {
                        Label(experiment == .tokens ? "計測する" : "実行する", systemImage: "play.fill")
                            .fontWeight(.semibold)
                    }
                    .disabled(!canRun)
                }
            }

            if runner.running || !runner.result.isEmpty || runner.error != nil {
                Section("結果") {
                    if runner.running { ProgressView("処理中") }
                    if !runner.result.isEmpty { Text(runner.result).textSelection(.enabled) }
                    if let error = runner.error {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }
            }

            if !runner.trace.isEmpty {
                Section("ツールの実行履歴") {
                    ForEach(Array(runner.trace.enumerated()), id: \.offset) { _, event in
                        Text(event).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
            }
        }
        .navigationTitle(experiment.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .task(id: pickerItem) { await loadPhoto() }
        .onDisappear { runner.cancel() }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                modelAvailability = SystemLanguageModel.default.availability
            }
        }
        .toolbar {
            Button {
                modelAvailability = SystemLanguageModel.default.availability
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel("モデルの状態を更新")
        }
    }

    private var canRun: Bool {
        experiment.supportedByOS && !experiment.requiresPhysicalDevice && modelAvailability == .available &&
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (!experiment.usesImage || (image != nil && !loadingImage))
    }

    private func loadPhoto() async {
        guard let item = pickerItem else { return }
        loadingImage = true
        image = nil
        photoError = nil
        defer {
            if pickerItem == item { loadingImage = false }
        }
        do {
            let data = try await item.loadTransferable(type: Data.self)
            try Task.checkCancellation()
            guard pickerItem == item else { return }
            guard let data, let photo = UIImage(data: data) else {
                photoError = "選んだ画像を開けませんでした。"
                return
            }
            image = photo
        } catch {
            if !Task.isCancelled && pickerItem == item {
                photoError = "写真を読み込めませんでした。もう一度選んでください。"
            }
        }
    }
}

private func statusMessage(_ availability: SystemLanguageModel.Availability) -> String {
    switch availability {
    case .available: "モデルを利用できます"
    case .unavailable(.deviceNotEligible): "この環境はApple Intelligenceに非対応です"
    case .unavailable(.appleIntelligenceNotEnabled): "設定でApple Intelligenceをオンにしてください"
    case .unavailable(.modelNotReady): "モデルの準備が完了するまでお待ちください"
    @unknown default: "モデルの状態を取得できません"
    }
}

@MainActor
private enum DemoFlyer {
    static func make() -> UIImage {
        let size = CGSize(width: 540, height: 370)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.systemIndigo.setFill()
            context.fill(CGRect(x: 0, y: 0, width: size.width, height: 12))
            draw("ロボット展示会", at: CGPoint(x: 34, y: 48), size: 48, weight: .bold)
            draw("ROBOT EXPO", at: CGPoint(x: 36, y: 115), size: 24, weight: .semibold)
            draw("11月25日  13:00", at: CGPoint(x: 36, y: 195), size: 29, weight: .medium)
            draw("会場  北キャンパス", at: CGPoint(x: 36, y: 248), size: 24, weight: .regular)
            draw("入場無料", at: CGPoint(x: 36, y: 295), size: 24, weight: .regular)

            let filter = CIFilter.qrCodeGenerator()
            filter.message = Data("ROBOT-EXPO-NORTH-CAMPUS".utf8)
            if let output = filter.outputImage {
                let scaled = output.transformed(by: CGAffineTransform(scaleX: 5, y: 5))
                if let qr = CIContext().createCGImage(scaled, from: scaled.extent) {
                    UIImage(cgImage: qr).draw(at: CGPoint(x: 350, y: 176))
                }
            }
        }
    }

    private static func draw(_ text: String, at point: CGPoint, size: CGFloat, weight: UIFont.Weight) {
        (text as NSString).draw(at: point, withAttributes: [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: UIColor.black
        ])
    }
}
