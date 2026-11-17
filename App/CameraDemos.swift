@preconcurrency import AVFoundation
import CoreImage
import SwiftUI
import Vision

final class DemoCamera: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()
    let queue = DispatchQueue(label: "lab.camera")
    private var generation = UUID()
    private let lock = NSLock()

    func start(type: AVCaptureDevice.DeviceType, position: AVCaptureDevice.Position,
               setup: @escaping @Sendable (AVCaptureSession, DispatchQueue) throws -> Void,
               status: @escaping @MainActor @Sendable (String?) -> Void) {
        let id = lock.withLock {
            generation = UUID()
            return generation
        }
        AVCaptureDevice.requestAccess(for: .video) { [self] allowed in
            queue.async { [self] in
                guard lock.withLock({ generation == id }) else { return }
                do {
                    guard allowed else { throw DemoError.unavailable("設定でカメラへのアクセスを許可してください。") }
                    guard let camera = AVCaptureDevice.default(type, for: .video, position: position) else {
                        throw DemoError.unavailable("このカメラを搭載したiPhone実機が必要です。")
                    }
                    session.beginConfiguration()
                    do {
                        session.inputs.forEach { session.removeInput($0) }
                        session.outputs.forEach { session.removeOutput($0) }
                        session.sessionPreset = .vga640x480
                        let input = try AVCaptureDeviceInput(device: camera)
                        guard session.canAddInput(input) else { throw DemoError.unavailable("カメラを利用できません。") }
                        session.addInput(input)
                        try setup(session, queue)
                    } catch {
                        session.commitConfiguration()
                        throw error
                    }
                    session.commitConfiguration()
                    if lock.withLock({ generation == id }) { session.startRunning() }
                    Task { @MainActor in status(nil) }
                } catch {
                    Task { @MainActor in status(error.localizedDescription) }
                }
            }
        }
    }

    func stop() {
        lock.withLock { generation = UUID() }
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class Surface: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        override func layoutSubviews() {
            super.layoutSubviews()
            if let connection = preview.connection, connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }
    }

    func makeUIView(context: Context) -> Surface {
        let view = Surface()
        view.backgroundColor = .black
        view.preview.videoGravity = .resizeAspectFill
        view.preview.session = session
        return view
    }

    func updateUIView(_ view: Surface, context: Context) {}
}

private struct DepthDot: Sendable {
    let u: Double
    let v: Double
    let x: Double
    let y: Double
    let z: Double
}

private final class DepthReader: NSObject, AVCaptureDepthDataOutputDelegate, @unchecked Sendable {
    let deliver: @Sendable ([DepthDot]) -> Void
    init(deliver: @escaping @Sendable ([DepthDot]) -> Void) { self.deliver = deliver }

    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depth: AVDepthData,
                         timestamp: CMTime, connection: AVCaptureConnection) {
        let frame = depth.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        guard let calibration = frame.cameraCalibrationData else { return }
        let map = frame.depthDataMap
        CVPixelBufferLockBaseAddress(map, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(map, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(map) else { return }
        let width = CVPixelBufferGetWidth(map)
        let height = CVPixelBufferGetHeight(map)
        let stride = CVPixelBufferGetBytesPerRow(map) / MemoryLayout<Float>.stride
        let values = base.assumingMemoryBound(to: Float.self)
        let intrinsics = calibration.intrinsicMatrix
        let reference = calibration.intrinsicMatrixReferenceDimensions
        let sx = Double(reference.width) / Double(width)
        let sy = Double(reference.height) / Double(height)
        let fx = Double(intrinsics[0][0]), fy = Double(intrinsics[1][1])
        let cx = Double(intrinsics[2][0]), cy = Double(intrinsics[2][1])
        let step = max(3, width / 60)
        var dots: [DepthDot] = []
        for row in Swift.stride(from: 0, to: height, by: step) {
            for col in Swift.stride(from: 0, to: width, by: step) {
                let z = Double(values[row * stride + col])
                guard z.isFinite, (0.12...1.5).contains(z) else { continue }
                let x = (Double(col) * sx - cx) / fx * z
                let y = (Double(row) * sy - cy) / fy * z
                dots.append(.init(u: Double(row) / Double(height), v: Double(col) / Double(width), x: y, y: x, z: z))
            }
        }
        deliver(dots)
    }
}

struct DepthDemo: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var camera = DemoCamera()
    @State private var reader: DepthReader?
    @State private var dots: [DepthDot] = []
    @State private var status = "TrueDepthを起動中…"
    @State private var spatial = false
    @State private var yaw = 0.45

    var body: some View {
        DemoScreen(title: "顔を3Dの点群で見る", instruction: "前面カメラに顔や手を近づけてください。立体モードは横にドラッグすると回転します。") {
            Picker("表示", selection: $spatial) {
                Text("距離マップ").tag(false)
                Text("3D点群").tag(true)
            }
            .pickerStyle(.segmented)

            Canvas { context, size in
                let side = min(size.width, size.height)
                for dot in dots {
                    let x: Double
                    let y: Double
                    if spatial {
                        let depth = dot.z - 0.45
                        x = size.width / 2 + (dot.x * cos(yaw) - depth * sin(yaw)) * side * 2.2
                        y = size.height / 2 + dot.y * side * 2.2
                    } else {
                        x = dot.u * size.width
                        y = dot.v * size.height
                    }
                    let hue = min(0.72, max(0.02, (dot.z - 0.18) * 1.15))
                    context.fill(Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)),
                                 with: .color(Color(hue: hue, saturation: 0.78, brightness: 1)))
                }
            }
            .frame(maxHeight: .infinity)
            .background(.black, in: RoundedRectangle(cornerRadius: 18))
            .clipShape(.rect(cornerRadius: 18))
            .gesture(DragGesture().onChanged { if spatial { yaw = Double($0.translation.width) / 100 + 0.45 } })
            .accessibilityLabel("リアルタイム深度点群")
            DemoStatus(message: dots.isEmpty ? status : "近い  ● 赤　　遠い  ● 青")
        }
        .onAppear { start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { camera.stop(); reader = nil }
            if phase == .active && reader == nil { start() }
        }
        .onDisappear { camera.stop(); reader = nil; dots = [] }
    }

    private func start() {
        let delegate = DepthReader { dots in
            Task { @MainActor in if reader != nil { self.dots = dots } }
        }
        reader = delegate
        camera.start(type: .builtInTrueDepthCamera, position: .front) { session, queue in
            let output = AVCaptureDepthDataOutput()
            output.isFilteringEnabled = true
            guard session.canAddOutput(output) else { throw DemoError.unavailable("深度データを取得できません。") }
            session.addOutput(output)
            output.setDelegate(delegate, callbackQueue: queue)
            output.connection(with: .depthData)?.isEnabled = true
        } status: { status = $0 ?? "顔や手をカメラに向けてください。" }
    }
}

private final class HandReader: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let request = VNDetectHumanHandPoseRequest()
    private var last = CMTime.invalid
    let deliver: @Sendable (CGPoint?, Double) -> Void

    init(deliver: @escaping @Sendable (CGPoint?, Double) -> Void) {
        self.deliver = deliver
        super.init()
        request.maximumHandCount = 1
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput buffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let time = buffer.presentationTimeStamp
        if last.isValid && (time - last).seconds < 0.055 { return }
        last = time
        let handler = VNImageRequestHandler(cmSampleBuffer: buffer, orientation: .up)
        guard (try? handler.perform([request])) != nil,
              let hand = request.results?.first,
              let thumb = try? hand.recognizedPoint(.thumbTip),
              let finger = try? hand.recognizedPoint(.indexTip),
              thumb.confidence > 0.3, finger.confidence > 0.3 else {
            deliver(nil, .infinity)
            return
        }
        let a = thumb.location
        let b = finger.location
        deliver(CGPoint(x: (a.x + b.x) / 2, y: 1 - (a.y + b.y) / 2), hypot(a.x - b.x, a.y - b.y))
    }
}

struct AirDrawDemo: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var camera = DemoCamera()
    @State private var reader: HandReader?
    @State private var strokes: [[CGPoint]] = []
    @State private var cursor: CGPoint?
    @State private var drawing = false
    @State private var status = "カメラを起動中…"

    var body: some View {
        DemoScreen(title: "空中に絵を描く", instruction: "前面カメラに手を向け、親指と人差し指をつまんで動かします。指を離すと線が止まります。") {
            GeometryReader { proxy in
                CameraPreview(session: camera.session)
                    .overlay {
                        Canvas { context, size in
                            let scale = max(size.width / 480, size.height / 640)
                            let content = CGSize(width: 480 * scale, height: 640 * scale)
                            func position(_ p: CGPoint) -> CGPoint {
                                CGPoint(x: p.x * content.width + (size.width - content.width) / 2,
                                        y: p.y * content.height + (size.height - content.height) / 2)
                            }
                            for stroke in strokes {
                                guard let first = stroke.first else { continue }
                                var path = Path()
                                path.move(to: position(first))
                                for point in stroke.dropFirst() { path.addLine(to: position(point)) }
                                context.stroke(path, with: .color(.mint), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                            }
                            if let cursor {
                                let p = position(cursor)
                                context.fill(Path(ellipseIn: CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14)),
                                             with: .color(drawing ? .mint : .white))
                            }
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
            .clipShape(.rect(cornerRadius: 18))
            DemoStatus(message: drawing ? "描画中" : cursor == nil ? status : "指をつまむと描画")
            Button("描いた線を消す", systemImage: "eraser") { strokes = []; drawing = false }
                .buttonStyle(.bordered)
        }
        .onAppear { start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { camera.stop(); reader = nil }
            if phase == .active && reader == nil { start() }
        }
        .onDisappear { camera.stop(); reader = nil }
    }

    private func start() {
        let delegate = HandReader { point, distance in
            Task { @MainActor in
                guard reader != nil else { return }
                cursor = point
                guard let point, distance < (drawing ? 0.065 : 0.043) else { drawing = false; return }
                if !drawing { strokes.append([]); drawing = true }
                if strokes.count > 100 { strokes.removeFirst() }
                let index = strokes.count - 1
                if strokes[index].count < 3000 { strokes[index].append(point) }
            }
        }
        reader = delegate
        camera.start(type: .builtInWideAngleCamera, position: .front) { session, queue in
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            guard session.canAddOutput(output) else { throw DemoError.unavailable("映像を取得できません。") }
            session.addOutput(output)
            output.setSampleBufferDelegate(delegate, queue: queue)
            if let connection = output.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = true
                }
            }
        } status: { status = $0 ?? "手をカメラに向けてください。" }
    }
}
