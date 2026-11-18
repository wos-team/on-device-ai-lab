import SwiftUI

struct TechnologyGuide {
    let name: String
    let capability: String
    let demo: String
    let applications: String
    let notes: Notes

    init(_ name: String, _ capability: String, _ demo: String, _ applications: String, notes: Notes) {
        self.name = name
        self.capability = capability
        self.demo = demo
        self.applications = applications
        self.notes = notes
    }

    static let depth = Self("TrueDepth · AVFoundation",
        "前面の赤外線センサーを使い、画像の各位置に対応する距離を取得できます。AVFoundationは深度マップとカメラの校正情報を読み出す窓口です。",
        "距離を色に変換し、校正情報から各画素を3D座標に戻して点群を描きます。",
        "手を前後に動かすジェスチャー、人物と背景の分離、近距離の形状プレビューに応用できます。", notes: .depth)
    static let hand = Self("Vision · VNDetectHumanHandPoseRequest",
        "カメラ映像から手首や指の関節位置を2D座標と信頼度で取得できます。",
        "親指と人差し指の距離を手の大きさで補正してつまみ動作を判定し、指先の中点を線にします。",
        "画面に触れないスライド操作、手の動きを使う楽器、運動練習のフィードバックに応用できます。", notes: .hand)
    static let sound = Self("Sound Analysis · SNClassifySoundRequest",
        "マイクや音声ファイルを短い区間に分け、学習済みモデルで音の種類と信頼度を推定できます。",
        "拍手と笑い声の候補を拾い、短い間隔で続く検出をまとめて花火やダンスを起動します。",
        "通知音や犬の鳴き声への反応、録音の検索タグ、専用モデルを使った機械音の分類に応用できます。", notes: .sound)
    static let placement = Self("ARKit · RealityKit",
        "ARKitはカメラと動きの情報から端末の位置や床・机などの面を推定します。RealityKitはその座標に3Dモデルを描画できます。",
        "タップした方向にレイを飛ばし、見つかった水平面にロボットを固定します。",
        "家具の試し置き、作業手順の重ね表示、空間を使ったゲームに応用できます。", notes: .placement)
    static let body = Self("ARKit · ARBodyTrackingConfiguration",
        "背面カメラに映る人の身体を追跡し、腰や腕、脚などの関節の3D変換を推定できます。",
        "関節間の向きと長さを使って、RealityKitで組み立てたロボットを人の隣で動かします。",
        "アバターの操作、ダンスやスポーツのフォーム表示、キャラクターアニメーションの下書きに応用できます。", notes: .body)
    static let face = Self("ARKit · ARFaceAnchor",
        "顔の位置・形状と、左右の目の閉じ具合や顎の開き具合を表すブレンドシェイプ係数を取得できます。",
        "片目を閉じたときに横移動し、口を開いたときにジャンプするように係数をゲーム操作へ変換します。",
        "表情で動くアバター、手を使わない操作、表情に反応するカメラ効果に応用できます。", notes: .face)
    static let marble = Self("Core Motion · Core Haptics",
        "Core Motionで端末に対する重力の方向を取得できます。Core Hapticsでは振動の強さ、鋭さ、タイミングを指定できます。",
        "傾きでビー玉を加速させ、壁に当たる速さから振動と効果音の強さを計算します。",
        "ダイヤルの目盛りの手触り、ゲーム内の路面の違い、視線を向けずに分かる操作の反応に応用できます。", notes: .marble)
    static let maze = Self("PHASE · PHASEOccluder",
        "3D空間に音源と聴き手を置き、方向や距離に応じた音を再生できます。遮蔽物には形状や材質を指定できます。",
        "迷路で聴き手を移動させ、コンクリートの壁を置いた場合と外した場合の音の違いを聞けます。",
        "音を頼りに進むゲーム、AR展示の案内、仮想空間の環境音に応用できます。", notes: .maze)
    static let video = Self("Wi-Fi Aware · Network",
        "対応端末をペアリングし、アクセスポイントなしで暗号化された直接通信を確立できます。Networkで通信路を使います。",
        "カメラ役がJPEGフレームを送り、モニター役が受け取った順に表示します。",
        "現場のカメラ映像の確認、近くの端末へのファイル共有、外部機器の操作に応用できます。", notes: .video)
    static let treasure = Self("Nearby Interaction · UWB",
        "対応機器同士でトークンを交換し、近くの相手までの距離や利用可能な方向を継続して取得できます。",
        "Multipeer Connectivityで相手を選んでトークンを交換し、UWBの測定値を距離と矢印で表示します。",
        "待ち合わせ相手の案内、対応アクセサリの探索、近づくと反応する展示に応用できます。", notes: .treasure)
}

struct TechnologyGuideButton: View {
    let guide: TechnologyGuide
    @State private var showing = false

    var body: some View {
        Button("技術と応用を見る", systemImage: "info.circle") { showing = true }
            .font(.subheadline)
            .sheet(isPresented: $showing) {
                NavigationStack {
                    List {
                        Section("使っている技術") {
                            Text(guide.name).font(.headline)
                            Text(guide.capability)
                        }
                        Section("このデモでの使い方") { Text(guide.demo) }
                        Section("仕組みとデータの流れ") {
                            Text(guide.notes.mechanism)
                            Text(guide.notes.workflow)
                        }
                        Section("別の用途への応用") {
                            Text(guide.applications)
                            Text(guide.notes.examples)
                        }
                        Section("実装・検証のポイント") { Text(guide.notes.considerations) }
                        Section("Apple公式資料") {
                            ForEach(guide.notes.references, id: \.title) { reference in
                                Link(destination: reference.url) {
                                    Label(reference.title, systemImage: "arrow.up.right.square")
                                }
                            }
                        }
                    }
                    .navigationTitle("技術と応用")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("閉じる") { showing = false }
                        }
                    }
                }
            }
    }
}

extension Experiment {
    var technology: TechnologyGuide {
        switch self {
        case .generate:
            .init("Foundation Models · LanguageModelSession", "端末内の言語モデルに指示と入力を渡して文章を生成できます。", "展示会の情報から日本語の告知文の下書きを作ります。", "連絡文、商品説明、イベント案内の下書きに使えます。", notes: .generate)
        case .summarize:
            .init("Foundation Models · LanguageModelSession", "渡した文章を指示に沿って圧縮できます。生成結果は原文と照合できます。", "予定、集合場所、持ち物などを原文から拾い、短く並べます。", "長いお知らせや日報を、後で原文と一緒に確認できる要点にできます。", notes: .summarize)
        case .rewrite:
            .init("Foundation Models · LanguageModelSession", "文の意味を保つよう指示しつつ、語調や書き方を変えられます。", "くだけた依頼文を丁寧な日本語に整えます。", "専門的な文章をやさしい言葉に置き換えたり、読み手に合わせて案内の文体を変えたりできます。", notes: .rewrite)
        case .classify:
            .init("Foundation Models · Guided Generation", "Swiftの列挙型でモデルが選べるカテゴリを定義できます。", "問い合わせを不具合、機能要望、質問の3種類から選ばせます。", "受信した依頼の振り分けや、メモの整理に使えます。", notes: .classify)
        case .tagging:
            .init("Foundation Models · contentTagging", "タグ付け向けのモデルで、文から話題、物、行動、感情を拾えます。", "短い観察メモを4種類のタグに分けます。", "日記や活動記録を横断検索するためのタグを補えます。", notes: .tagging)
        case .structured:
            .init("Foundation Models · @Generable", "回答の構造をSwiftの型で定義し、生成結果を型付きデータとして受け取れます。", "依頼文から件名、期限、相手、急ぎかどうかを別々の項目にします。", "カレンダー登録の下書きや、申請フォームの入力候補を作れます。", notes: .structured)
        case .stream:
            .init("Foundation Models · streamResponse", "文章が生成される途中のスナップショットを順次受け取れます。", "短い物語が伸びていく過程を画面に出します。", "下書きやチャットで、応答が完成する前から読み始められます。", notes: .stream)
        case .streamStructured:
            .init("Foundation Models · 構造化ストリーミング", "型付きデータの各項目を、揃ったものから順次表示できます。", "生成途中のタスク項目を表示し、残りの項目が埋まる様子を見せます。", "長い文面からフォームやチェックリストを作る途中経過の表示に使えます。", notes: .streamStructured)
        case .chat:
            .init("Foundation Models · セッション履歴", "同じセッションに前の発言を含め、文脈を使った応答を生成できます。履歴は入力上限の一部を占めます。", "最初に伝えたロボットの名前を次のやり取りで尋ねられます。", "旅行の条件を詰める対話や、文章を段階的に直す画面に使えます。", notes: .chat)
        case .tools:
            .init("Foundation Models · Tool", "モデルがアプリ側で登録された関数を、型付きの引数で呼び出せます。", "架空の施設データを問い合わせて、開室時間と利用条件を回答に使います。", "在庫状況、営業時間、自分のデータベースの検索結果を応答に取り込めます。", notes: .tools)
        case .spotlight:
            .init("Core Spotlight · SpotlightSearchTool", "アプリが端末内に索引付けした資料を、モデルが検索できます。", "サンプル案内に登録した受付場所や時刻を検索して答えます。", "オフラインの取扱説明書や保存済み授業資料を質問から探せます。", notes: .spotlight)
        case .tokens:
            .init("Foundation Models · tokenCount", "文字列をモデルが処理する単位に換算し、入力のトークン数を計測できます。", "入力の計測値と、端末内モデルのセッション上限を並べます。", "入力が長い場合に文書を分割したり、古い会話履歴を整理したりする目安にできます。", notes: .tokens)
        case .profiles:
            .init("Foundation Models · DynamicProfile", "セッションのやり取りを引き継いで、モデルへの指示や利用できるツールを切り替えられます。", "同じ会話で一文の回答と例付きの箇条書きの指示を切り替えます。", "同じ相談を整理する段階と要約する段階で、応答の役割を変えられます。", notes: .profiles)
        case .vision:
            .init("Foundation Models · 画像添付", "モデルに画像と質問を渡し、写っている内容や構図を説明させられます。", "ポスターのレイアウトや用途について画像を見ながら答えます。", "写真の説明文の下書きや、掲示物の概要の把握に使えます。", notes: .vision)
        case .ocr:
            .init("Vision · OCRTool", "画像中の文字をVisionで検出し、読み取った文字列をモデルに渡せます。", "ポスター内の文字を読み取り、行に分けて表示します。", "レシートの項目を転記したり、掲示物の文字をコピーできる形にしたりできます。", notes: .ocr)
        case .barcode:
            .init("Vision · BarcodeReaderTool", "画像からQRコードなどを検出し、埋め込まれている値を読み出せます。", "ポスターのQRコードを読み取り、内容を文字列として表示します。", "備品コードの読み取りや、イベントの受付記録に使えます。", notes: .barcode)
        }
    }
}
