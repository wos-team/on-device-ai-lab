import SwiftUI

enum Experiment: String, CaseIterable, Identifiable {
    case generate = "文章生成"
    case summarize = "要約"
    case rewrite = "書き換え"
    case classify = "分類"
    case tagging = "タグ付け"
    case structured = "構造化抽出"
    case stream = "文章ストリーミング"
    case streamStructured = "構造化ストリーミング"
    case chat = "会話と履歴"
    case tools = "ツール呼び出し"
    case spotlight = "Spotlight検索"
    case tokens = "トークン計測"
    case profiles = "動的プロファイル"
    case vision = "画像理解"
    case ocr = "画像から文字を読む"
    case barcode = "QRコードを読む"

    static let sections: [(String, [Self])] = [
        ("テキスト", [.generate, .summarize, .rewrite, .classify, .tagging]),
        ("出力と会話", [.structured, .stream, .streamStructured, .chat]),
        ("アプリ連携", [.tools, .spotlight, .tokens, .profiles]),
        ("画像", [.vision, .ocr, .barcode])
    ]

    var id: Self { self }

    var symbol: String {
        switch self {
        case .generate: "text.badge.plus"
        case .summarize: "text.alignleft"
        case .rewrite: "pencil.line"
        case .classify: "tray.full"
        case .tagging: "tag"
        case .structured: "list.bullet.rectangle"
        case .stream: "text.cursor"
        case .streamStructured: "list.bullet.indent"
        case .chat: "bubble.left.and.bubble.right"
        case .tools: "wrench.and.screwdriver"
        case .spotlight: "magnifyingglass"
        case .tokens: "number"
        case .profiles: "slider.horizontal.3"
        case .vision: "photo"
        case .ocr: "text.viewfinder"
        case .barcode: "qrcode.viewfinder"
        }
    }

    var detail: String {
        switch self {
        case .generate: "指示から新しい文章を生成します。"
        case .summarize: "入力から要点を取り出して短くします。"
        case .rewrite: "意味を保ちながら、口調や言い回しを変えます。"
        case .classify: "入力を指定したカテゴリから一つ選んで分類します。"
        case .tagging: "Appleのコンテンツタグ付け用モデルを使います。"
        case .structured: "@Generable で定義したタスクの項目を取り出します。"
        case .stream: "応答の途中経過を画面に表示します。"
        case .streamStructured: "タスクの項目が埋まっていく様子を表示します。"
        case .chat: "同じセッションで前の発言を覚えているか試せます。"
        case .tools: "モデルが架空の研究室案内を検索します。実際に呼んだツールと引数を表示します。"
        case .spotlight: "アプリが登録したサンプル資料を検索し、内容に基づいて答えます。"
        case .tokens: "入力のトークン数と、この端末のコンテキスト上限を比較します。"
        case .profiles: "会話履歴を維持したまま、応答の指示を切り替えます。"
        case .vision: "画像を添付して、写っているものについて質問します。"
        case .ocr: "モデルが Vision の OCRTool を呼び、画像の文字を読み取ります。"
        case .barcode: "モデルが Vision の BarcodeReaderTool を呼び、コードの内容を読み取ります。"
        }
    }

    var sample: String {
        switch self {
        case .generate: "大学のロボット展示会を紹介する短い告知文を書いて。"
        case .summarize: "来週の木曜に工作室の見学会を行います。集合は13時に正門です。参加希望者は火曜までにフォームで申し込み、当日は学生証を持参してください。雨天でも実施します。"
        case .rewrite: "明日の打ち合わせ、15時にずらせる？ 変更できそうなら教えて。"
        case .classify: "ログインのボタンを押すと画面が真っ白になります。"
        case .tagging: "望遠鏡を使って月のクレーターを観察し、写真を撮影した。"
        case .structured, .streamStructured: "11月25日までに田中さんへ展示会の見積もりを送る。急ぎでお願いします。"
        case .stream: "夜の図書館を舞台に、200字くらいの短い物語を書いて。"
        case .chat: "私が考えたロボットの名前はミントです。次の質問まで覚えておいて。"
        case .tools: "工作室の開室時間と、利用に必要なものを案内してください。"
        case .spotlight: "ロボット展示会の受付はどこで何時からですか？ 案内を検索してください。"
        case .tokens: "Apple Intelligenceのモデルが、この日本語を何トークンとして数えるか調べます。"
        case .profiles: "スマートフォンのバッテリーが寒いと減りやすい理由を説明して。"
        case .vision: "画像のレイアウトと、どんな案内なのかを日本語で説明して。"
        case .ocr: "OCRツールを使って画像内の文字を読み取り、改行を付けてそのまま表示して。"
        case .barcode: "バーコード読み取りツールを使い、画像のQRコードに入っている値を表示して。"
        }
    }

    var minimum: String? {
        switch self {
        case .tokens: "iOS 26.4"
        case .profiles, .spotlight, .vision, .ocr, .barcode: "iOS 27"
        default: nil
        }
    }

    var supportedByOS: Bool {
        switch self {
        case .tokens: if #available(iOS 26.4, *) { true } else { false }
        case .profiles, .spotlight, .vision, .ocr, .barcode: if #available(iOS 27, *) { true } else { false }
        default: true
        }
    }

    var requiresPhysicalDevice: Bool {
        #if targetEnvironment(simulator)
        [.spotlight, .ocr, .barcode].contains(self)
        #else
        false
        #endif
    }

    var usesImage: Bool { [.vision, .ocr, .barcode].contains(self) }
    var keepsHistory: Bool { self == .chat || self == .profiles }
}
