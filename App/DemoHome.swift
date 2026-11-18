import SwiftUI

struct DemoHome: View {
    var body: some View {
        List {
            Section("Apple Intelligence") {
                NavigationLink {
                    CatalogView()
                } label: {
                    DemoRow(title: "ローカルLLM基本機能", subtitle: "文章・画像・ツール呼び出しなど、16種類", icon: "sparkles")
                }
            }
            Section("このiPhoneで試す") {
                link("顔を3Dの点群で見る", "TrueDepth · 顔や手の近さを色と立体で見る", "point.3.connected.trianglepath.dotted") { DepthDemo() }
                link("空中に絵を描く", "Vision · 指をつまんで線を描く", "hand.draw") { AirDrawDemo() }
                link("拍手で花火", "Sound Analysis · 拍手と笑い声で遊ぶ", "waveform") { SoundDemo() }
                link("机にロボットを置く", "ARKit · ミニチュアを横から見る", "arkit") { PlacementDemo() }
                link("体でロボットを動かす", "ARKit · 背面カメラで全身を追う", "figure.dance") { BodyDemo() }
                link("まばたきゲーム", "ARKit · 左右のまばたきと口で操作", "eye") { BlinkDemo() }
                link("ビー玉の手触り", "Core Haptics · 傾けて壁に当てる", "circle.circle") { MarbleDemo() }
                link("耳でたどる迷路", "PHASE · 音の方向と壁越しの違いを聞く", "headphones") { AudioMazeDemo() }
            }
            Section("iPhoneを2台使う") {
                link("近くの端末へライブ映像", "Wi-Fi Aware · 1台はカメラ、もう1台はモニター", "video") { NearbyVideoDemo() }
                link("iPhoneで宝探し", "Nearby Interaction · 距離と方向を頼りに探す", "location.viewfinder") { TreasureDemo() }
            }
        }
        .navigationTitle("Apple機能ラボ")
    }

    private func link<Destination: View>(
        _ title: String, _ subtitle: String, _ icon: String, @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            DemoRow(title: title, subtitle: subtitle, icon: icon)
        }
    }
}

private struct DemoRow: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } icon: {
            Image(systemName: icon).foregroundStyle(.indigo)
        }
    }
}

struct DemoScreen<Content: View>: View {
    let title: String
    let instruction: String
    let guide: TechnologyGuide
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 16) {
            Text(instruction)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            TechnologyGuideButton(guide: guide)
                .frame(maxWidth: .infinity, alignment: .leading)
            content
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DemoStatus: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .accessibilityAddTraits(.updatesFrequently)
    }
}

enum DemoError: LocalizedError {
    case unavailable(String)

    var errorDescription: String? {
        switch self { case .unavailable(let message): message }
    }
}
