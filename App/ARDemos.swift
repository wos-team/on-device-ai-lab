@preconcurrency import ARKit
import AVFoundation
import RealityKit
import SwiftUI

@MainActor
private func box(_ size: SIMD3<Float>, _ color: UIColor, radius: Float = 0.01) -> ModelEntity {
    ModelEntity(mesh: .generateBox(size: size, cornerRadius: radius), materials: [SimpleMaterial(color: color, isMetallic: false)])
}

@MainActor
private func ball(_ radius: Float, _ color: UIColor) -> ModelEntity {
    ModelEntity(mesh: .generateSphere(radius: radius), materials: [SimpleMaterial(color: color, isMetallic: false)])
}

@MainActor
private func positioned(_ entity: ModelEntity, _ position: SIMD3<Float>, in parent: Entity) {
    entity.position = position
    parent.addChild(entity)
}

struct PlacementDemo: View {
    @State private var status = "机や床にカメラを向けてください。"

    var body: some View {
        DemoScreen(title: "机にロボットを置く", instruction: "机や床にゆっくりカメラを向け、置きたい場所をタップ。横に移動して、ロボットを別の角度から見てください。") {
            if ARWorldTrackingConfiguration.isSupported {
                PlacementSurface { status = $0 }
                    .clipShape(.rect(cornerRadius: 18))
                DemoStatus(message: status)
            } else {
                ContentUnavailableView("対応するiPhone実機が必要です", systemImage: "arkit")
            }
        }
    }
}

private struct PlacementSurface: UIViewRepresentable {
    let status: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(status: status) }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        context.coordinator.view = view
        view.session.delegate = context.coordinator
        view.session.delegateQueue = .main
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        view.session.run(config)
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.place(_:))))
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {}
    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) { view.session.pause() }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency ARSessionDelegate {
        weak var view: ARView?
        let status: (String) -> Void
        var anchor: AnchorEntity?

        init(status: @escaping (String) -> Void) { self.status = status }

        @objc func place(_ gesture: UITapGestureRecognizer) {
            guard let view else { return }
            let point = gesture.location(in: view)
            guard let hit = view.raycast(from: point, allowing: .existingPlaneGeometry, alignment: .horizontal).first
                    ?? view.raycast(from: point, allowing: .estimatedPlane, alignment: .horizontal).first else {
                status("面を探しています。明るい場所でカメラをゆっくり動かしてください。")
                return
            }
            anchor?.removeFromParent()
            let anchor = AnchorEntity(world: hit.worldTransform)
            let robot = Entity()
            positioned(box([0.21, 0.018, 0.17], .systemTeal), [0, 0.009, 0], in: robot)
            positioned(box([0.11, 0.11, 0.075], .systemIndigo), [0, 0.102, 0], in: robot)
            positioned(box([0.125, 0.085, 0.09], .systemPurple), [0, 0.194, 0], in: robot)
            for side: Float in [-1, 1] {
                positioned(box([0.033, 0.064, 0.05], .systemIndigo), [side * 0.035, 0.046, 0.01], in: robot)
                positioned(box([0.025, 0.075, 0.035], .systemPink), [side * 0.071, 0.113, 0], in: robot)
                positioned(ball(0.011, .white), [side * 0.028, 0.199, 0.043], in: robot)
            }
            positioned(ball(0.014, .systemYellow), [0, 0.248, 0], in: robot)
            anchor.addChild(robot)
            view.scene.addAnchor(anchor)
            self.anchor = anchor
            status("配置できました。横からのぞき込むか、別の場所をタップしてください。")
        }

        func session(_ session: ARSession, didFailWithError error: Error) { status(error.localizedDescription) }
    }
}

struct BodyDemo: View {
    @State private var status = "カメラの前に友達の全身が入るようにしてください。"

    var body: some View {
        DemoScreen(title: "体でロボットを動かす", instruction: "友達に2〜3m離れて立ってもらい、手を振ったり踊ったりしてみてください。ロボットがその場でまねします。") {
            if ARBodyTrackingConfiguration.isSupported {
                BodySurface { status = $0 }
                    .clipShape(.rect(cornerRadius: 18))
                DemoStatus(message: status)
            } else {
                ContentUnavailableView("全身トラッキング対応のiPhoneが必要です", systemImage: "figure.dance")
            }
        }
    }
}

private struct BodySurface: UIViewRepresentable {
    let status: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(status: status) }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        view.session.delegate = context.coordinator
        view.session.delegateQueue = .main
        context.coordinator.view = view
        view.session.run(ARBodyTrackingConfiguration())
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {}
    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) { view.session.pause() }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency ARSessionDelegate {
        private struct Limb {
            let from: String
            let to: String
            let entity: ModelEntity
        }

        weak var view: ARView?
        let status: (String) -> Void
        private var anchor: AnchorEntity?
        private var head: ModelEntity?
        private var limbs: [Limb] = []

        init(status: @escaping (String) -> Void) { self.status = status }

        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) { update(anchors) }
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) { update(anchors) }
        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            guard anchors.contains(where: { $0 is ARBodyAnchor }) else { return }
            anchor?.isEnabled = false
            status("全身が画面に入る位置に戻ってください。")
        }

        func session(_ session: ARSession, didFailWithError error: Error) { status(error.localizedDescription) }

        private func update(_ anchors: [ARAnchor]) {
            guard let view, let body = anchors.compactMap({ $0 as? ARBodyAnchor }).first else { return }
            guard body.isTracked else { anchor?.isEnabled = false; return }

            let skeleton = body.skeleton
            func joint(_ name: String) -> SIMD3<Float>? {
                guard let transform = skeleton.modelTransform(for: ARSkeleton.JointName(rawValue: name)) else { return nil }
                return SIMD3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            }
            guard let headPosition = joint("head_joint") else { return }
            if anchor == nil { makeRobot(in: view) }
            guard let anchor else { return }
            var transform = body.transform
            // Offset the robot to the person's right so both remain visible.
            transform.columns.3 += body.transform.columns.0 * 0.65
            anchor.transform = Transform(matrix: transform)
            anchor.isEnabled = true
            head?.position = headPosition
            for limb in limbs {
                guard let from = joint(limb.from), let to = joint(limb.to) else {
                    limb.entity.isEnabled = false
                    continue
                }
                let delta = to - from
                let length = simd_length(delta)
                guard length.isFinite && length > 0.001 else {
                    limb.entity.isEnabled = false
                    continue
                }
                limb.entity.isEnabled = true
                limb.entity.position = (to + from) / 2
                limb.entity.orientation = simd_quatf(from: [0, 1, 0], to: delta / length)
                limb.entity.scale.y = length
            }
            status("トラッキング中。腕や足を動かすとロボットも動きます。")
        }

        private func makeRobot(in view: ARView) {
            let anchor = AnchorEntity(world: SIMD3<Float>.zero)
            let head = box([0.22, 0.22, 0.19], .systemPurple, radius: 0.035)
            for side: Float in [-1, 1] {
                positioned(ball(0.022, .white), [side * 0.05, 0.028, 0.095], in: head)
            }
            anchor.addChild(head)
            self.head = head

            var pairs: [(String, String)] = [("hips_joint", "neck_1_joint")]
            for side in ["left", "right"] {
                pairs.append(contentsOf: [
                    ("neck_1_joint", "\(side)_arm_joint"),
                    ("\(side)_arm_joint", "\(side)_forearm_joint"),
                    ("\(side)_forearm_joint", "\(side)_hand_joint"),
                    ("hips_joint", "\(side)_upLeg_joint"),
                    ("\(side)_upLeg_joint", "\(side)_leg_joint"),
                    ("\(side)_leg_joint", "\(side)_foot_joint")
                ])
            }
            limbs = pairs.enumerated().map { index, pair in
                let width: Float = index == 0 ? 0.21 : 0.075
                let entity = box([width, 1, width * 0.8], index == 0 ? .systemIndigo : .systemTeal)
                anchor.addChild(entity)
                return Limb(from: pair.0, to: pair.1, entity: entity)
            }
            self.anchor = anchor
            view.scene.addAnchor(anchor)
        }
    }
}

struct BlinkDemo: View {
    @State private var lane = 1
    @State private var star = 2
    @State private var score = 0
    @State private var jumping = false
    @State private var status = "正面を向いて顔を映してください。"
    @State private var landing: Task<Void, Never>?

    var body: some View {
        DemoScreen(title: "まばたきゲーム", instruction: "左目・右目だけを閉じて移動。星の下で口を開けるとジャンプして取れます。") {
            if ARFaceTrackingConfiguration.isSupported {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 18).fill(.indigo.gradient)
                    HStack(spacing: 0) {
                        ForEach(0..<3) { index in
                            VStack {
                                Spacer()
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow).opacity(star == index ? 1 : 0)
                                Spacer().frame(height: 45)
                                Image(systemName: "hare.fill")
                                    .foregroundStyle(.white).opacity(lane == index ? 1 : 0)
                                    .offset(y: jumping && lane == index ? -70 : 0)
                            }
                            .font(.system(size: 40, weight: .bold))
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.bottom, 28)
                    .animation(.spring, value: lane)
                    Text("スコア  \(score)")
                        .font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding()
                }
                .accessibilityLabel("まばたきゲーム。スコア \(score)")
                FaceSurface(action: act, status: { status = $0 })
                    .frame(width: 100, height: 120)
                    .clipShape(.rect(cornerRadius: 12))
                DemoStatus(message: status)
            } else {
                ContentUnavailableView("表情トラッキング対応のiPhoneが必要です", systemImage: "eye")
            }
        }
        .onDisappear { landing?.cancel(); jumping = false }
    }

    private func act(_ action: FaceSurface.Move) {
        switch action {
        case .left: lane = max(0, lane - 1)
        case .right: lane = min(2, lane + 1)
        case .jump:
            guard !jumping else { return }
            withAnimation(.easeOut(duration: 0.18)) { jumping = true }
            if lane == star {
                score += 1
                star = (star + Int.random(in: 1...2)) % 3
            }
            landing = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                withAnimation(.easeIn(duration: 0.18)) { jumping = false }
            }
        }
    }
}

private struct FaceSurface: UIViewRepresentable {
    enum Move { case left, right, jump }
    let action: (Move) -> Void
    let status: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(action: action, status: status) }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        view.session.delegate = context.coordinator
        view.session.delegateQueue = .main
        view.session.run(ARFaceTrackingConfiguration())
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {}
    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) { view.session.pause() }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency ARSessionDelegate {
        let action: (Move) -> Void
        let status: (String) -> Void
        private var eyesReady = true
        private var mouthReady = true

        init(action: @escaping (Move) -> Void, status: @escaping (String) -> Void) {
            self.action = action
            self.status = status
        }

        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            guard let face = anchors.compactMap({ $0 as? ARFaceAnchor }).first, face.isTracked else {
                status("顔をカメラに向けてください。")
                return
            }
            let left = face.blendShapes[.eyeBlinkLeft]?.doubleValue ?? 0
            let right = face.blendShapes[.eyeBlinkRight]?.doubleValue ?? 0
            let jaw = face.blendShapes[.jawOpen]?.doubleValue ?? 0
            if left < 0.24 && right < 0.24 { eyesReady = true }
            if eyesReady && left > 0.72 && right < 0.28 { eyesReady = false; action(.left) }
            if eyesReady && right > 0.72 && left < 0.28 { eyesReady = false; action(.right) }
            if jaw < 0.19 { mouthReady = true }
            if mouthReady && jaw > 0.42 { mouthReady = false; action(.jump) }
            status("顔を検出中 · 左目／右目／口")
        }

        func session(_ session: ARSession, didFailWithError error: Error) { status(error.localizedDescription) }
    }
}
