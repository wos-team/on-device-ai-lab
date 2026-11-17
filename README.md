# オンデバイスAIラボ

Apple Intelligence のオンデバイスモデルを、16種類の実験で触れる日本語の iPhone アプリです。すべての画面に編集できるサンプルがあり、画像の実験には OCR と QR コード用のサンプル画像も入っています。推論に使うのは Apple の `SystemLanguageModel` です。APIキーやアプリ独自のサーバーは不要です。

| iOS | 試せること |
| --- | --- |
| 26.0+ | 文章生成、要約、書き換え、分類、タグ付け、構造化抽出、文章ストリーミング、構造化ストリーミング、会話と履歴、独自ツール呼び出し |
| 26.4+ | 入力トークン数とコンテキスト上限の計測 |
| 27.0+ | 動的プロファイル、Spotlight検索、画像理解、OCR、QRコード読み取り |

## 起動

1. このリポジトリをクローンし、Xcode 27 以降で `OnDeviceAILab.xcodeproj` を開きます。
2. `OnDeviceAILab` ターゲットの **Signing & Capabilities** で自分の Apple ID の Team を選びます。必要に応じて Bundle Identifier を変更します。
3. Apple Intelligence 対応の iPhone を選び、Run を押します。iPhone 側の設定で Apple Intelligence を有効にし、モデルの準備が完了していることを確認します。
4. 一覧から実験を開き、**実行する** を押します。

シミュレータでも画面を確認できます。モデルが利用できない環境では理由が表示され、実行ボタンが無効になります。

## 実験の見どころ

- **構造化ストリーミング**ではタスク名、期限、相手、急ぎかどうかの各フィールドを、生成途中から表示します。
- **会話と履歴**では最初のサンプルを送信してから **前の発言について聞く** を押すと、名前を覚えているか試せます。
- **動的プロファイル**ではセッションを保ったまま、一文での回答と例付きの箇条書きを切り替えられます。
- **ツール呼び出し**、**Spotlight検索**、**OCR**、**QRコードを読む**では、モデルが実際にツールを呼んだときに引数と結果を表示します。画像のサンプルに埋め込まれたQRコードの値は `ROBOT-EXPO-NORTH-CAMPUS` です。
- Spotlight検索の実験は、検索用に架空の資料3件をアプリのローカルインデックスへ登録します。会話は画面内のセッションに保持します。

[Apple Foundation Models](https://developer.apple.com/documentation/foundationmodels) · [iOS 27の画像入力と動的プロファイル](https://developer.apple.com/videos/play/wwdc2026/241/) · [Spotlight連携](https://developer.apple.com/videos/play/wwdc2026/246/)
