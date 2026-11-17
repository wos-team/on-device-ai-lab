import AVFoundation
import ModelIO
import PHASE
import SwiftUI
import simd

@MainActor
@Observable
private final class MazeAudio {
    var position = SIMD2<Int>(0, 0)
    var status = "音を鳴らして迷路を開始します。"
    var playing = false
    var won = false
    private var engine: PHASEEngine?
    private var listener: PHASEListener?
    private var occluder: PHASEOccluder?
    private var event: PHASESoundEvent?
    private let goal = SIMD2<Int>(0, -3)
    private let halls: Set<SIMD2<Int>> = [
        .init(0, 0), .init(1, 0), .init(2, 0), .init(-1, 0),
        .init(2, -1), .init(2, -2), .init(2, -3), .init(1, -3), .init(0, -3),
        .init(3, -1), .init(3, -2)
    ]

    func start() {
        stop()
        position = .zero
        won = false
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.playback, mode: .default, options: .mixWithOthers)
            try audio.setActive(true)
            let engine = PHASEEngine(updateMode: .automatic)
            let listener = PHASEListener(engine: engine)
            try engine.rootObject.addChild(listener)
            let source = PHASESource(engine: engine)
            source.transform = pose(x: Float(goal.x), z: Float(goal.y))
            try engine.rootObject.addChild(source)

            let mesh = MDLMesh(boxWithExtent: [3, 2.6, 1.7], segments: [1, 1, 1],
                               inwardNormals: false, geometryType: .triangles, allocator: nil)
            let shape = PHASEShape(engine: engine, mesh: mesh, materials: [PHASEMaterial(engine: engine, preset: .concrete)])
            let wall = PHASEOccluder(engine: engine, shapes: [shape])
            wall.transform = pose(x: 0, z: -1.5)
            try engine.rootObject.addChild(wall)

            guard let pipeline = PHASESpatialPipeline(flags: .directPathTransmission),
                  let url = Bundle.main.url(forResource: "MazeBeacon", withExtension: "wav") else {
                throw DemoError.unavailable("空間オーディオを準備できません。")
            }
            let mixer = PHASESpatialMixerDefinition(spatialPipeline: pipeline)
            mixer.distanceModelParameters = PHASEGeometricSpreadingDistanceModelParameters()
            let asset = try engine.assetRegistry.registerSoundAsset(url: url, identifier: "beacon",
                                                                      assetType: .resident, channelLayout: nil, normalizationMode: .none)
            let sampler = PHASESamplerNodeDefinition(soundAssetIdentifier: asset.identifier, mixerDefinition: mixer)
            sampler.playbackMode = .looping
            let node = try engine.assetRegistry.registerSoundEventAsset(rootNode: sampler, identifier: "mazeLoop")
            let parameters = PHASEMixerParameters()
            parameters.addSpatialMixerParameters(identifier: mixer.identifier, source: source, listener: listener)
            let event = try PHASESoundEvent(engine: engine, assetIdentifier: node.identifier, mixerParameters: parameters)
            try engine.start()
            self.engine = engine
            self.listener = listener
            self.occluder = wall
            self.event = event
            event.start(completion: nil)
            playing = true
            status = "音を頼りに進んでください。"
        } catch {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            status = error.localizedDescription
        }
    }

    func stop() {
        guard playing else { return }
        event?.stopAndInvalidate()
        engine?.stop()
        event = nil
        listener = nil
        occluder = nil
        engine = nil
        playing = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func setWall(_ enabled: Bool) {
        occluder?.transform = pose(x: enabled ? 0 : 50, z: -1.5)
    }

    func move(_ step: SIMD2<Int>) {
        guard playing && !won else { return }
        let next = position &+ step
        guard halls.contains(next) else { status = "壁です。別の方向へ進んでください。"; return }
        position = next
        listener?.transform = pose(x: Float(position.x), z: Float(position.y))
        won = position == goal
        status = won ? "ゴール！ 音源にたどり着きました。" : "1歩進みました。"
        if won { stop() }
    }

    private func pose(x: Float, z: Float) -> simd_float4x4 {
        var matrix = matrix_identity_float4x4
        matrix.columns.3 = [x, 0, z, 1]
        return matrix
    }
}

struct AudioMazeDemo: View {
    @State private var maze = MazeAudio()
    @State private var wall = true
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        DemoScreen(title: "耳でたどる迷路", instruction: "イヤホンで音の方向を聞き、矢印で1歩ずつ進んでください。遮音を切り替えると、同じ位置で壁越しの音を比べられます。") {
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(.indigo.gradient)
                Image(systemName: maze.won ? "flag.checkered" : "headphones")
                    .font(.system(size: 76, weight: .light))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
            VStack(spacing: 7) {
                arrow("上", "arrow.up", [0, -1])
                HStack {
                    arrow("左", "arrow.left", [-1, 0])
                    arrow("下", "arrow.down", [0, 1])
                    arrow("右", "arrow.right", [1, 0])
                }
            }
            .disabled(!maze.playing)
            Toggle("壁の遮音", isOn: $wall)
                .onChange(of: wall) { _, enabled in maze.setWall(enabled) }
            DemoStatus(message: maze.status)
            Button(maze.playing ? "音を停止" : "迷路を開始", systemImage: maze.playing ? "stop.fill" : "play.fill") {
                if maze.playing { maze.stop() } else { maze.start(); maze.setWall(wall) }
            }
            .buttonStyle(.borderedProminent)
        }
        .onDisappear { maze.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { maze.stop() }
        }
    }

    private func arrow(_ label: String, _ icon: String, _ direction: SIMD2<Int>) -> some View {
        Button { maze.move(direction) } label: {
            Image(systemName: icon).frame(width: 40, height: 32)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(label)
    }
}
