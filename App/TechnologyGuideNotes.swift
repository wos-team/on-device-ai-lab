import Foundation

extension TechnologyGuide {
    struct Notes {
        struct Reference {
            let title: String
            let url: URL

            init(_ title: String, _ path: String) {
                self.title = title
                // These are fixed paths to Apple Developer documentation.
                self.url = URL(string: "https://developer.apple.com/documentation/" + path)!
            }
        }

        let mechanism: String
        let workflow: String
        let examples: String
        let considerations: String
        let references: [Reference]

        static let depth = Self(
            mechanism: "深度マップは画素ごとの距離を並べた配列です。カメラの内部パラメータから各画素の視線方向を求め、その方向に測定した距離を当てはめると、カメラ基準の3D座標になります。",
            workflow: "このデモでは12cmから1.5mまでの有効な点を間引いて描画します。距離マップでは色が奥行きを表し、点群では左右に回したときの位置の違いから形の凹凸が分かります。",
            examples: "手を近づけて仮想スイッチを押す操作なら、画面上の位置に加えて距離のしきい値を使えます。背景をぼかす用途なら、カラー映像と深度の位置・時刻を合わせ、前景の境界を滑らかにします。",
            considerations: "反射する物体や測定範囲の外では点が抜けることがあります。寸法を測る用途では、対象の材質や距離を変えて実測値と比較し、欠測時の表示も用意します。",
            references: [
                .init("TrueDepthの深度データ取得", "avfoundation/streaming-depth-data-from-the-truedepth-camera"),
                .init("AVDepthDataのAPI", "avfoundation/avdepthdata")
            ]
        )

        static let hand = Self(
            mechanism: "Visionが返すのは、指先や手首の座標と検出の信頼度です。座標は画像基準なので、映像を鏡像にしたりトリミングしたりするときは、描画側も同じ変換を使います。",
            workflow: "指先同士の距離を手首から指の付け根までの距離で割り、手が大きく映るほど判定が甘くなるのを抑えます。つまみ開始を連続フレームで確認し、解除には別のしきい値を使います。",
            examples: "スライド操作なら、つまみを確定操作にして移動量でページ送りを判定できます。楽器なら指先の位置を音程、つまみの開き具合を音量に対応させられます。",
            considerations: "指の重なりや逆光で認識が途切れる場合があります。低信頼度の点で操作を確定させず、現在検出できている指をカーソルで示すと、利用者が手の位置を調整できます。",
            references: [
                .init("Visionの手のポーズ検出", "vision/detecting-hand-poses-with-vision"),
                .init("手のポーズ検出API", "vision/vndetecthumanhandposerequest")
            ]
        )

        static let sound = Self(
            mechanism: "音声分類器は短い区間ごとに候補と信頼度を返します。分析区間を重ねると短い音を拾いやすくなりますが、一度の音が複数の結果に現れることがあります。",
            workflow: "このデモでは上位候補から拍手や笑い声を探し、同じ候補の連続検出をまとめます。拍手なら花火、笑い声ならロボットの動きに変換します。",
            examples: "録音整理なら、検出カテゴリに時刻を添えて検索結果から再生できます。機械の作動音など標準分類器にない音には、用途に合わせたCore MLモデルを渡す方法があります。",
            considerations: "信頼度の値だけでは実際の正答率は分かりません。用途の騒音やマイク距離で、拾いたい音と誤反応しそうな音を使って評価します。",
            references: [
                .init("Sound Analysisの概要", "soundanalysis"),
                .init("標準モデルでライブ音声を分類", "soundanalysis/classifying-live-audio-input-with-a-built-in-sound-classifier")
            ]
        )

        static let placement = Self(
            mechanism: "ARKitはカメラの特徴点と慣性センサーを使い、端末が空間内でどう動いたかを推定します。RealityKitは同じ座標系にモデルを描くため、端末を動かすと見る角度が変わります。",
            workflow: "画面をタップすると、ARKitのレイキャストでタップ方向と水平面の交点を探します。その場所にアンカーを作り、ロボットの部品をアンカー基準で配置します。",
            examples: "家具の試し置きなら実寸モデルと床のアンカーを組み合わせます。設備の案内なら、機器の位置に手順を重ね、作業者が視点を変えても同じ箇所を指せます。",
            considerations: "模様の少ない面や暗い場所では面を検出しにくくなります。面が見つかるまで置ける場所を案内し、置いた後に位置を直せる操作を用意します。",
            references: [
                .init("ARで物を置くサンプル", "arkit/placing-objects-and-handling-3d-interaction"),
                .init("RealityKitの概要", "realitykit")
            ]
        )

        static let body = Self(
            mechanism: "ARKitは背面カメラの映像から身体を追跡し、腰を基準とした関節の3D変換を得られます。各関節の変換と、人物全体の空間内の位置は別々に扱います。",
            workflow: "このデモは有効な関節の位置を前フレームと混ぜて揺れを抑え、肩と肘の間などにロボットの部品を向けます。人から横にずらして、本人の動きと見比べられるようにします。",
            examples: "ダンスの練習なら、腕や脚の角度を時間軸に並べて見本と比較できます。アバターに適用する場合は、キャラクターの関節構造に動きを割り当てます。",
            considerations: "手足が身体の後ろに隠れたり全身が画角から外れたりすると、推定が不安定になります。追跡できない関節は表示を弱め、欠けた測定値を動作評価に含めない設計が考えられます。",
            references: [
                .init("3Dモーションキャプチャのサンプル", "arkit/capturing-body-motion-in-3d"),
                .init("ARBodyAnchorのAPI", "arkit/arbodyanchor")
            ]
        )

        static let face = Self(
            mechanism: "顔トラッキングでは、左右の目や顎などの動きを個別の係数として取得できます。アプリがその連続値を、アニメーションや離散的な操作に変換します。",
            workflow: "このゲームでは片目だけ強く閉じたときに横移動し、顎が一定以上開くとジャンプします。目や顎を元に戻すまで次の入力を受け付けないため、同じ表情を続けても操作が連発しません。",
            examples: "アバターなら係数をそのまま表情の強さに使えます。非接触操作なら、一つの顔動作で候補を移動し、別の動作で確定する入力方式が考えられます。",
            considerations: "人によって動かしやすい表情や自然な係数が違います。実用品では初回に本人の動きでしきい値を調整でき、タッチなどでも同じ操作ができると使いやすくなります。",
            references: [
                .init("顔と表情のトラッキング", "arkit/tracking-and-visualizing-faces"),
                .init("ARFaceAnchorのAPI", "arkit/arfaceanchor")
            ]
        )

        static let marble = Self(
            mechanism: "Core Motionが推定した重力ベクトルを利用すると、画面のどの方向に端末が傾いているかを計算できます。Core Hapticsは短い衝撃と持続する振動をパターンとして再生できます。",
            workflow: "重力の画面方向成分でビー玉を加速し、壁では速度を反転しながら減速させます。壁に垂直な速度から、衝撃時の振動の強さと鋭さ、効果音の音量と再生速度を決めます。",
            examples: "ダイヤルなら目盛りを越えるたびに軽い振動を返し、端まで回したときだけ強めにできます。ゲームなら路面の細かな振動と衝突時の強い衝撃を分けられます。",
            considerations: "振動に対応しない機器では表示と音で結果を伝えます。振動や効果音を個別に止められる設定があると、使う場所に合わせられます。",
            references: [
                .init("衝突に合わせた振動パターン", "corehaptics/playing-collision-based-haptic-patterns"),
                .init("Core Motionの概要", "coremotion")
            ]
        )

        static let maze = Self(
            mechanism: "PHASEでは音を鳴らす位置と聞く位置を3D座標で管理します。位置関係による音量や聞こえる方向に加え、間にある物体の形や材質による遮音を設定できます。",
            workflow: "迷路では音源をゴールに固定し、矢印を押した方向へ聴き手を動かします。「壁の遮音」で物体の有無を切り替えると、同じ位置で壁越しの変化を比較できます。",
            examples: "展示の音声ガイドなら、展示物の場所から声が聞こえるように配置できます。ゲームなら、壁の向こうの足音が弱まり、角を回ると聞き取りやすくなる演出を作れます。",
            considerations: "方向の違いは出力機器や環境で感じ方が変わります。イヤホンで左右と距離を確かめ、方向だけで操作の成否が決まる設計には視覚などの補助も用意できます。",
            references: [
                .init("3D空間の音源と遮音", "phase/playing-sound-from-a-location-in-a-3d-scene"),
                .init("PHASEOccluderのAPI", "phase/phaseoccluder")
            ]
        )

        static let video = Self(
            mechanism: "Wi-Fi Awareは近くの機器をペアリングし、アクセスポイントを経由しない通信路を作ります。サービスを公開する側と探す側を決め、Networkフレームワークでデータを送受信します。",
            workflow: "カメラ役は一定間隔で画像をJPEGにして、データ長と本体を送ります。モニター役は長さを読み、次の画像の区切りを判定して画面を更新します。",
            examples: "工具の手元を別端末で確認するモニターや、回線のない展示会場でのファイル受け渡しが考えられます。映像を滑らかにするなら、連続映像の圧縮や通信状況に合わせた画質調整を検討できます。",
            considerations: "2台の対応端末、システムのペアリングと署名権限が必要です。再接続や送信停止を見える操作にし、受信側ではサイズの上限を設けると扱いやすくなります。",
            references: [
                .init("Wi-Fi Awareの導入と署名権限", "wifiaware/adopting-wi-fi-aware"),
                .init("ペアリング済みの端末を接続する", "wifiaware/connecting-paired-devices")
            ]
        )

        static let treasure = Self(
            mechanism: "Multipeer Connectivityは相手端末の発見とトークン交換に使います。測距はその後にNearby Interactionが担当し、UWBで距離と、測定可能なときは方向を得ます。",
            workflow: "相手を選択し接続を承認すると、トークンを交換して測距を始めます。距離と方向は連続更新されるため、直前の測定と混ぜて表示の揺れを抑えます。",
            examples: "展示では、作品の位置に近づいた時点で端末の案内を切り替えられます。機材の探索なら、方向が取れない間も距離の増減から近づいているか伝えられます。",
            considerations: "持ち方、遮蔽物、相手の位置で方向が取得できないことがあります。距離だけ取得できる状態と、相手を完全に見失った状態を区別して案内する設計が役立ちます。",
            references: [
                .init("Nearby Interactionの精密探索", "nearbyinteraction/finding-devices-with-precision"),
                .init("端末の発見とトークン交換", "nearbyinteraction/discovering-peers-with-multipeer-connectivity")
            ]
        )

        static let generate = Self(
            mechanism: "アプリがモデルに役割や文体を指定し、入力に合わせて文章を生成します。同じ入力でも、指示や生成設定によって出力が変わります。",
            workflow: "告知文の例では、書いてほしい内容を入力して日本語の文章を得ます。会場や日付を入力すると、含めるべき事実と文章表現を分けて試せます。",
            examples: "商品紹介なら商品情報と対象読者を入力し、複数の紹介文を選べるようにできます。メールなら相手と要件を入力し、送信前に編集できる下書きにします。",
            considerations: "入力にない日時や条件を生成することがあります。実際に配布する文章は、日付・固有名詞・数値を入力と照合してから確定します。",
            references: [
                .init("文章生成とタスクの実行", "foundationmodels/generating-content-and-performing-tasks-with-foundation-models"),
                .init("SystemLanguageModelのAPI", "foundationmodels/systemlanguagemodel")
            ]
        )

        static let summarize = Self(
            mechanism: "要約では、モデルが重要と判断した情報を生成し直します。誰が読むか、何に使うか、何項目に絞るかを指定すると、残したい情報を伝えられます。",
            workflow: "このデモは、日時・場所・締切・持ち物を優先し、3項目以内にまとめるよう指定します。数字や固有名詞を原文と見比べて、必要な情報が残ったか確認できます。",
            examples: "会議メモなら決定事項と担当を別項目にできます。複数の週報を集約するなら、各文書を先に要約し、原文への参照とともに全体の傾向を表示できます。",
            considerations: "長い文書はセッション上限に収まるよう分ける必要があります。結論に必要な条件が前後にまたがる場合は、区切りに少し重なりを持たせます。",
            references: [
                .init("文章生成とタスクの実行", "foundationmodels/generating-content-and-performing-tasks-with-foundation-models"),
                .init("Foundation Modelsの概要", "foundationmodels")
            ]
        )

        static let rewrite = Self(
            mechanism: "文章の言い換えでは、変えてよい要素と保つ要素を明示できます。語調、文章の長さ、読み手の知識に合わせて指示を変えます。",
            workflow: "このデモでは依頼の条件や日時を残し、丁寧な言い回しだけを生成します。依頼の強さや意味が変わっていないか、原文と比べられます。",
            examples: "社内の専門文を来場者向けに書き換えたり、長い説明をアプリ内の短い案内文に整えたりできます。複数の丁寧さを選べる入力欄にも応用できます。",
            considerations: "言い換えで否定や例外が抜けると、原文と異なる意味になります。重要な文章では元の文もすぐ参照できるようにします。",
            references: [
                .init("文章生成とタスクの実行", "foundationmodels/generating-content-and-performing-tasks-with-foundation-models"),
                .init("Foundation Modelsの概要", "foundationmodels")
            ]
        )

        static let classify = Self(
            mechanism: "カテゴリを列挙型で定義すると、出力を画面の表示名や処理ルートに直接結び付けられます。判断の境目は指示の例で補えます。",
            workflow: "不具合、機能要望、質問それぞれの定義を与え、問い合わせを一つに分類します。アプリは型の値を受け取り、日本語のカテゴリ名を表示します。",
            examples: "問い合わせの担当チームを選んだり、メモを活動・買い物・調べものに分けたりできます。利用者が選び直した結果を、次の改善に活用できます。",
            considerations: "複数の要件を含む問い合わせでは一分類に絞りにくくなります。実用品では複数カテゴリや判断保留をスキーマに加えられます。",
            references: [
                .init("Swiftの型に沿った生成", "foundationmodels/generating-swift-data-structures-with-guided-generation"),
                .init("GenerableのAPI", "foundationmodels/generable")
            ]
        )

        static let tagging = Self(
            mechanism: "タグは一つの文章に複数付けられます。短い説明から話題、物、行動、感情をそれぞれ取り出し、検索や絞り込みに使えます。",
            workflow: "専用のコンテンツタグ付けモデルに観察メモを渡し、4種類の配列として受け取ります。タグが得られなかった項目は空欄として扱います。",
            examples: "活動日誌なら「運動」「雨」などのタグで別の日の記録を探せます。写真の説明文にタグを付けて、被写体や活動別にまとめることもできます。",
            considerations: "似た意味を別の語で返すことがあります。検索に使う場合は、既存タグとの統合や利用者が編集できる機能が役立ちます。",
            references: [
                .init("コンテンツタグの生成", "foundationmodels/categorizing-and-organizing-data-with-content-tags"),
                .init("Foundation Modelsの概要", "foundationmodels")
            ]
        )

        static let structured = Self(
            mechanism: "@Generableでフィールドと型を定義し、モデルにその構造の値を生成させます。画面に出す文字列を分割して値を取り出す手間を減らせます。",
            workflow: "依頼文から件名・期限・相手・緊急度を取り出します。期限と相手が明記されていない場合には空文字を使うよう、各項目の指示に含めています。",
            examples: "予定の下書きでは日時・場所・参加者を分けて表示できます。申請フォームなら、長い相談メモから項目候補を作り、人が不足する値を補えます。",
            considerations: "型が正しくても、相対日付の解釈や人物名が正しいとは限りません。登録前に値を検証し、必要に応じて日付や氏名を確認します。",
            references: [
                .init("Swiftの型に沿った生成", "foundationmodels/generating-swift-data-structures-with-guided-generation"),
                .init("GenerableのAPI", "foundationmodels/generable")
            ]
        )

        static let stream = Self(
            mechanism: "ストリームは生成中の状態を順次返すので、応答が完成する前に表示できます。表示側は新しいスナップショットで前回までの文章を更新します。",
            workflow: "このデモでは短い物語を生成しながら表示します。ストリーミングによって、待機表示から文章へ切り替わるまでの時間を短くできます。",
            examples: "長い案内や対話なら、先に届いた部分を読みながら続きの生成を待てます。途中から不要になったときに停止できる操作も組み合わせられます。",
            considerations: "表示途中は文が終わっていない場合があります。コピーや保存の確定は生成が完了したか分かる形にすると扱いやすくなります。",
            references: [
                .init("Foundation Modelsの概要", "foundationmodels"),
                .init("LanguageModelSessionのAPI", "foundationmodels/languagemodelsession")
            ]
        )

        static let streamStructured = Self(
            mechanism: "構造化ストリーミングでは、生成中の型付きデータを受け取れます。各項目の準備状況を別々に表せるため、完成を待つ間も画面を更新できます。",
            workflow: "依頼文から生成中のタスク項目を表示し、値のない欄は空のまま、届いた欄から順に埋めます。",
            examples: "長い報告書の整理では、先に届く見出しや担当者をプレビューできます。入力支援なら、どの欄がまだ処理中か示しながらフォームを組み立てられます。",
            considerations: "途中の値は完成後に変わる場合があります。途中状態の表示と、確定済みのデータを保存する操作を分けます。",
            references: [
                .init("Swiftの型に沿った生成", "foundationmodels/generating-swift-data-structures-with-guided-generation"),
                .init("LanguageModelSessionのAPI", "foundationmodels/languagemodelsession")
            ]
        )

        static let chat = Self(
            mechanism: "セッションは発言や応答を履歴に保持できます。次の入力時に先ほどの名前や条件が文脈に残っていると、それを踏まえて応答できます。",
            workflow: "ロボットの名前を伝えた後、同じセッションで名前を尋ねます。会話をやり直すと履歴に依存した応答の違いを確かめられます。",
            examples: "旅行相談なら予算や移動手段を会話で詰められます。文章編集なら、前の下書きを参照しながら変更点だけ伝えられます。",
            considerations: "長い会話では履歴もコンテキストを消費します。古い発言を要約するか、必要な事実をアプリのデータに保持して適宜渡す方法があります。",
            references: [
                .init("LanguageModelSessionのAPI", "foundationmodels/languagemodelsession"),
                .init("Foundation Modelsの概要", "foundationmodels")
            ]
        )

        static let tools = Self(
            mechanism: "ツールには名前、説明、引数の型を定義します。モデルは必要な引数を作ってツールを呼び、アプリが返した結果を使って応答を組み立てます。",
            workflow: "施設名をアプリの検索関数へ渡し、用意した開室時間を取り出します。ツール履歴を開くと、モデルが何を問い合わせたか確認できます。",
            examples: "最新の在庫や利用可能な予約枠を、回答時点でアプリから照会できます。計算や日程の重複確認など、同じ入力に同じ結果が必要な処理にも向きます。",
            considerations: "ツールに渡される値はアプリで検証します。在庫の参照と予約の確定を分け、状態を変更する操作は利用者が内容を確認してから行えるようにします。",
            references: [
                .init("モデルからのツール呼び出し", "foundationmodels/expanding-generation-with-tool-calling"),
                .init("ToolのAPI", "foundationmodels/tool")
            ]
        )

        static let spotlight = Self(
            mechanism: "Core Spotlightはアプリの内容を検索用の索引に登録できます。SpotlightSearchToolを使うと、モデルが質問に関連する登録済み資料を探せます。",
            workflow: "このデモはサンプル案内を索引に登録して、展示会の受付場所と時刻を検索します。検索結果がモデルに渡り、文章として表示されます。",
            examples: "説明書のどの箇所に解除手順があるか、講義資料のどこに締切が載っているか、といった質問をローカルの資料から調べられます。",
            considerations: "索引にない内容や更新前の情報を避けるには、元データの更新・削除に索引を追従させます。回答と一緒に参照した資料を開けるようにすると照合できます。",
            references: [
                .init("SpotlightSearchToolのAPI", "corespotlight/spotlightsearchtool"),
                .init("索引を自然言語で検索する", "corespotlight/searching-indexed-content-with-natural-language")
            ]
        )

        static let tokens = Self(
            mechanism: "トークンは、モデルが文章を読み書きする際の単位です。文字数との比率は言語や文字列で異なるので、実際の入力をモデルのAPIで計測します。",
            workflow: "この画面は現在の入力のトークン数とセッション上限を並べます。日本語と英語や、数字を含む長い文字列で数え方の違いを試せます。",
            examples: "文書を分割する境界や、会話履歴をまとめる時点の判断に使えます。応答のための余白を確保してから入力を組み立てる設計にも使えます。",
            considerations: "入力欄の文字列だけで全体が決まるわけではありません。システム指示や履歴、ツール定義、生成する出力も予算に含めます。",
            references: [
                .init("SystemLanguageModelのAPI", "foundationmodels/systemlanguagemodel"),
                .init("オンデバイスモデルのコンテキスト管理", "Technotes/tn3193-managing-the-on-device-foundation-model-s-context-window")
            ]
        )

        static let profiles = Self(
            mechanism: "動的プロファイルでは、会話の流れを引き継いで指示や使用可能なツールなどの設定を切り替えられます。",
            workflow: "このデモでは同じ相談の中で回答スタイルを変えます。短い一文と、例付きの説明を切り替えて返答の違いを見られます。",
            examples: "学習支援ならヒントを出す段階と要点を振り返る段階を分けられます。調べものでは、資料を探す段階と見つけた内容をまとめる段階で使う機能を変えられます。",
            considerations: "切り替えても以前の会話内容が影響します。どの応答を期待するかを画面で示し、設定変更後も一貫した振る舞いになるかテストします。",
            references: [
                .init("LanguageModelSessionのAPI", "foundationmodels/languagemodelsession"),
                .init("Foundation Modelsの概要", "foundationmodels")
            ]
        )

        static let vision = Self(
            mechanism: "画像と文章を同じプロンプトに含めると、モデルは質問に合わせて画像中の物や配置、全体の用途を説明できます。",
            workflow: "ポスターを添付し、レイアウトや案内の目的を尋ねます。同じ画像でも、色の配置、写っているもの、説明文の下書きなど、質問を変えて試せます。",
            examples: "写真の代替テキストの下書きや、作業写真の概要の整理に使えます。画像内の番号や小さな文字を扱うときは、OCRなどの専用機能も組み合わせられます。",
            considerations: "小さな対象やぼけた部分の説明は推測を含み得ます。「見えるものだけ」と指示したうえで、必要箇所の切り出しや原画像の参照も用意できます。",
            references: [
                .init("Foundation Modelsの概要", "foundationmodels"),
                .init("Visionの概要", "vision")
            ]
        )

        static let ocr = Self(
            mechanism: "OCRは画像の文字を検出し、文字列として読み出します。画像全体の意味を説明する処理と組み合わせると、文字の転記と用途の説明を分けられます。",
            workflow: "このデモではモデルにOCRツールの使用を求め、ポスターの文字を読み取ります。取り出した文字を行に分け、写真と照合できます。",
            examples: "レシートでは行を抽出して金額の候補を表示できます。掲示物では文字列をコピーできるようにして、検索や読み上げにつなげられます。",
            considerations: "斜めの撮影、小さい文字、似た形の文字で読み間違うことがあります。金額や番号を転記する用途は、結果と原画像を並べて確認できる形にします。",
            references: [
                .init("画像内の文字を認識する", "vision/recognizing-text-in-images"),
                .init("モデルからのツール呼び出し", "foundationmodels/expanding-generation-with-tool-calling")
            ]
        )

        static let barcode = Self(
            mechanism: "バーコード認識は、画像内の規格化されたパターンを検出し、読み取れる場合は埋め込まれた値を返します。",
            workflow: "このデモではモデルに読み取りツールを呼ばせ、ポスターに含まれるQRコードの値を表示します。ツールの結果と文章出力を見比べられます。",
            examples: "備品のコードを台帳のIDに対応付けたり、整理券コードを受付記録に紐付けたりできます。複数コードが映る場合は、位置を表示して選択できます。",
            considerations: "読み取れた値は単なる入力です。URLを勝手に開いたり、識別子だけで受付を確定したりせず、用途ごとの形式や照合結果を確認します。",
            references: [
                .init("VNDetectBarcodesRequestのAPI", "vision/vndetectbarcodesrequest"),
                .init("モデルからのツール呼び出し", "foundationmodels/expanding-generation-with-tool-calling")
            ]
        )
    }
}
