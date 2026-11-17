# Apple機能ラボ

Appleのフレームワークで何ができるかを、短い操作で体験する日本語のiPhoneアプリです。既存の16実験は **Apple Intelligence → ローカルLLM基本機能** にまとめています。

## すぐ試せるデモ

| デモ | やること | 体験できる機能 |
| --- | --- | --- |
| 顔を3Dの点群で見る | 前面カメラに顔や手を近づける。表示を切り替え、横にドラッグ | TrueDepthの実測距離。色分けした距離マップと回転できる3D点群 |
| 空中に絵を描く | 親指と人差し指をつまんで動かす | Visionの手のポーズ検出。つまむと描画、離すと停止 |
| 拍手で花火 | マイクをオンにして拍手する、笑う | Sound Analysisの標準分類器。拍手で花火、笑い声でロボットが踊る |
| 机にロボットを置く | カメラを机に向け、面をタップして横に移動 | ARKitの面検出とRealityKitの空間固定。約25cmのミニチュア |
| 体でロボットを動かす | 友達の全身を背面カメラに映す | ARKitの3D関節追跡。隣に表示される立体ロボットが動きをまねする |
| まばたきゲーム | 左目・右目だけを閉じて移動。口を開けてジャンプ | ARKitの表情係数。星の下でジャンプすると得点 |
| ビー玉の手触り | iPhoneを傾ける。弱い衝突と強い衝突をタップして比較も可能 | Core Motionの傾きとCore Haptics。壁に当たる速さで振動と音が変わる |
| 耳でたどる迷路 | イヤホンを付け、矢印で移動して音源を探す | PHASEの3D音源・距離減衰・コンクリート壁の遮音。遮音を切り替えて比較 |
| 近くの端末へライブ映像 | 2台でカメラ役とモニター役を選び、システムUIでペアリング | Wi-Fi Awareの直接通信。JPEGフレームを最大約8fpsで転送 |
| iPhoneで宝探し | 2台で端末を探し、一方で相手を選んで接続を許可 | Nearby InteractionのUWB測距。距離・方向・上下の案内 |

カメラやマイクは該当するデモで使用します。デモを閉じると停止します。宝探しは両方のアプリを画面に開いた状態で使います。ライブ映像を送る際は、ペアリング相手を確認してください。

## 起動

1. Xcode 27以降で `OnDeviceAILab.xcodeproj` を開きます。
2. `OnDeviceAILab` ターゲットの **Signing & Capabilities** で自分のTeamを選びます。
3. 接続したiPhoneを選んでRunを押します。
4. ホームから試したいデモを開きます。

iOS 26以降が対象です。TrueDepth、ARKit、UWB、振動などは対応するiPhone実機が必要です。ローカルLLMはApple Intelligence対応端末で有効化とモデルの準備が必要です。LLM内の画像・Spotlight・動的プロファイルはiOS 27以降、トークン計測は26.4以降で使えます。

### Wi-Fi Awareの署名

現在使用しているPersonal Teamでは、AppleからWi-Fi Aware capabilityの非対応エラーが返ります。通常ビルドではこの制約をデモ画面に表示します。

Apple Developer Programの対応Teamで、次のように付属の構成を指定するとWi-Fi Awareを有効にしたビルドを作れます。接続する両方の端末へインストールしてください。

```sh
xcodebuild   -project OnDeviceAILab.xcodeproj   -scheme OnDeviceAILab   -destination 'generic/platform=iOS'   -xcconfig WiFiAware.xcconfig   -allowProvisioningUpdates   DEVELOPMENT_TEAM=YOUR_TEAM_ID   build
```

`WiFiAware.xcconfig` は `WiFiAware.entitlements` のPublish／Subscribe権限とコンパイル条件を有効にします。サービス宣言は `Info.plist` にあります。ルーターを使わず、ペアリング済みのWi-Fi Aware端末間で通信します。

## ローカルLLM基本機能

文章生成、要約、書き換え、分類、話題・物・行動・感情のタグ付け、タスクの構造化抽出、文章ストリーミング、構造化ストリーミング、会話履歴、独自ツール呼び出し、Spotlight検索、トークン計測、動的プロファイル、画像理解、OCR、QR読み取りの16実験を収録しています。編集できるサンプル入力と画像を同梱しています。

## 検証

`DemoNavigationTests` はLLMの一覧と追加10デモを順に開き、衝突の比較操作、PHASE迷路の開始からゴールまでを確認します。ハードウェアからのセンサーデータ、マイク分類の精度、2台間通信は対応実機での確認が必要です。

## Appleの資料

- [TrueDepthの深度データ](https://developer.apple.com/documentation/avfoundation/streaming-depth-data-from-the-truedepth-camera)
- [手のポーズ検出](https://developer.apple.com/documentation/vision/detecting-hand-poses-with-vision)
- [Sound Analysis](https://developer.apple.com/documentation/soundanalysis)
- [ARで物を置く](https://developer.apple.com/documentation/arkit/placing-objects-and-handling-3d-interaction)
- [3Dモーションキャプチャ](https://developer.apple.com/documentation/arkit/capturing-body-motion-in-3d)
- [表情トラッキング](https://developer.apple.com/documentation/arkit/tracking-and-visualizing-faces)
- [Nearby Interaction](https://developer.apple.com/documentation/nearbyinteraction/finding-devices-with-precision)
- [Core Hapticsの衝突](https://developer.apple.com/documentation/corehaptics/playing-collision-based-haptic-patterns)
- [PHASEの3D空間と遮音](https://developer.apple.com/documentation/phase/playing-sound-from-a-location-in-a-3d-scene)
- [Wi-Fi Awareの導入](https://developer.apple.com/documentation/wifiaware/adopting-wi-fi-aware)
- [Foundation Models](https://developer.apple.com/documentation/foundationmodels)
