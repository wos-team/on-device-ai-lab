@preconcurrency import AVFoundation
import CoreImage
import DeviceDiscoveryUI
import Network
import os
import SwiftUI
import WiFiAware

private final class VideoEncoder: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let context = CIContext()
    private var last = CMTime.invalid
    let deliver: @Sendable (Data) -> Void
    init(deliver: @escaping @Sendable (Data) -> Void) { self.deliver = deliver }

    func captureOutput(_ output: AVCaptureOutput, didOutput buffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let time = buffer.presentationTimeStamp
        guard !last.isValid || (time - last).seconds > 0.125,
              let pixels = buffer.imageBuffer else { return }
        last = time
        let image = CIImage(cvPixelBuffer: pixels)
        guard let cgImage = context.createCGImage(image, from: image.extent),
              let jpeg = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.45) else { return }
        deliver(jpeg)
    }
}

private final class VideoMailbox: Sendable {
    private let state = OSAllocatedUnfairLock<AsyncStream<Data>.Continuation?>(initialState: nil)

    func frames() -> AsyncStream<Data> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            state.withLock {
                $0?.finish()
                $0 = continuation
            }
        }
    }

    func put(_ data: Data) { _ = state.withLock { $0?.yield(data) } }
    func finish() { state.withLock { $0?.finish(); $0 = nil } }
}

@MainActor
@Observable
private final class NearbyVideo {
    var status = "カメラ役とモニター役を1台ずつ選んでください。"
    var frame: UIImage?
    var active = false
    var frameCount = 0
    let camera = DemoCamera()
    private var encoder: VideoEncoder?
    private var task: Task<Void, Never>?
    private var sendTask: Task<Void, Never>?
    private let mailbox = VideoMailbox()

    var entitled: Bool {
        #if WIFI_AWARE_ENABLED
        true
        #else
        false
        #endif
    }
    var supported: Bool { WACapabilities.supportedFeatures.contains(.wifiAware) }

    func startCamera() {
        stop()
        guard entitled, supported, let service = WAPublishableService.allServices["_ailab-video._tcp"] else {
            status = "Wi-Fi Aware対応端末と、Wi-Fi Aware権限付きのビルドが必要です。"
            return
        }
        active = true
        frameCount = 0
        let mailbox = mailbox
        let encoder = VideoEncoder { data in mailbox.put(data) }
        self.encoder = encoder
        camera.start(type: .builtInWideAngleCamera, position: .back) { session, queue in
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            guard session.canAddOutput(output) else { throw DemoError.unavailable("カメラ映像を取得できません。") }
            session.addOutput(output)
            output.setSampleBufferDelegate(encoder, queue: queue)
            if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        } status: { [weak self] error in
            if let error { self?.stop(); self?.status = error }
        }

        task = Task {
            do {
                let listener = try NetworkListener(
                    for: .wifiAware(.connecting(to: service, from: .allPairedDevices)),
                    using: .parameters { TCP() }.wifiAware { $0.performanceMode = .realtime }.serviceClass(.interactiveVideo)
                )
                status = "モニター役で「カメラを選ぶ」を押してください。"
                try await listener.run { connection in
                    self.sendTask?.cancel()
                    self.sendTask = Task { await self.transmit(connection) }
                }
            } catch {
                if !Task.isCancelled { stop(); status = error.localizedDescription }
            }
        }
    }

    private func transmit(_ connection: NetworkConnection<TCP>) async {
        do {
            status = "接続しました。映像を送信中"
            for await jpeg in mailbox.frames() {
                try Task.checkCancellation()
                try await connection.send(UInt32(jpeg.count))
                try await connection.send(jpeg)
                frameCount += 1
            }
        } catch {
            if !Task.isCancelled { status = "映像送信が切れました。停止してから再接続してください。\n" + error.localizedDescription }
        }
    }

    func watch(_ endpoint: WAEndpoint) {
        stop()
        active = true
        frameCount = 0
        task = Task {
            do {
                let connection = NetworkConnection(to: endpoint, using: .parameters { TCP() }
                    .wifiAware { $0.performanceMode = .realtime }.serviceClass(.interactiveVideo))
                status = "映像を受信しています…"
                while !Task.isCancelled {
                    let length = try await connection.receive(as: UInt32.self).content
                    guard length > 0, length <= 2_000_000 else { throw DemoError.unavailable("映像フレームのサイズが不正です。") }
                    let data = try await connection.receive(exactly: Int(length)).content
                    guard let frame = UIImage(data: data) else { throw DemoError.unavailable("映像を読み込めませんでした。") }
                    self.frame = frame
                    frameCount += 1
                    status = "Wi-Fi Awareで受信中 · \(frameCount)フレーム"
                }
            } catch {
                if !Task.isCancelled { stop(); status = error.localizedDescription }
            }
        }
    }

    func stop() {
        task?.cancel()
        sendTask?.cancel()
        task = nil
        sendTask = nil
        camera.stop()
        encoder = nil
        mailbox.finish()
        active = false
        frame = nil
    }
}

struct NearbyVideoDemo: View {
    @State private var model = NearbyVideo()
    @State private var cameraRole = true
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        DemoScreen(title: "近くの端末へライブ映像", instruction: "両方のiPhoneでWi-FiとBluetoothをオンにします。1台をカメラ役にし、もう1台のモニター役でカメラを選んで接続してください。ルーターは不要です。", guide: .video) {
            Picker("役割", selection: $cameraRole) {
                Text("カメラ役").tag(true)
                Text("モニター役").tag(false)
            }
            .pickerStyle(.segmented)
            .onChange(of: cameraRole) { _, _ in model.stop() }

            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(.black)
                if cameraRole && model.active {
                    CameraPreview(session: model.camera.session).clipShape(.rect(cornerRadius: 18))
                } else if let frame = model.frame {
                    Image(uiImage: frame).resizable().scaledToFit()
                } else {
                    Image(systemName: cameraRole ? "video" : "display")
                        .font(.system(size: 60, weight: .light)).foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(maxHeight: .infinity)
            if !model.supported {
                DemoStatus(message: "Wi-Fi Awareに対応するiPhone 12以降など、対応する実機が必要です。")
            } else if !model.entitled {
                DemoStatus(message: "この署名ではWi-Fi Aware権限がありません。Apple Developer Programの対応Teamで、WiFiAware.xcconfigを指定してビルドしてください。")
            } else if cameraRole {
                if !model.active {
                    Button("カメラを開始", systemImage: "video.fill") { model.startCamera() }
                        .buttonStyle(.borderedProminent)
                } else if let service = WAPublishableService.allServices["_ailab-video._tcp"] {
                    DevicePairingView(.wifiAware(.connecting(to: service, from: .selected([])))) {
                        Label("モニター役からのペアリングを待つ", systemImage: "antenna.radiowaves.left.and.right")
                    } fallback: {
                        Text("ペアリングを開けませんでした。両方の端末でWi-FiとBluetoothを確認してください。")
                    }
                    Text("送信済み \(model.frameCount)フレーム").font(.caption).foregroundStyle(.secondary)
                }
            } else if !model.active, let service = WASubscribableService.allServices["_ailab-video._tcp"] {
                DevicePicker(.wifiAware(.connecting(to: .selected([]), from: service))) { endpoint in
                    model.watch(endpoint)
                } label: {
                    Label("カメラを選ぶ", systemImage: "video.badge.waveform")
                } fallback: {
                    Text("端末選択を開けませんでした。Wi-FiとBluetoothを確認してください。")
                }
            }
            DemoStatus(message: model.status)
            if model.active {
                Button("停止") { model.stop() }.buttonStyle(.bordered)
            }
        }
        .onDisappear { model.stop() }
        .onChange(of: scenePhase) { _, phase in if phase == .background { model.stop() } }
    }
}
