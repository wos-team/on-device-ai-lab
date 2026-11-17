@preconcurrency import AVFoundation
import CoreHaptics
import CoreMotion
@preconcurrency import SoundAnalysis
import SwiftUI

private final class SoundObserver: NSObject, SNResultsObserving, @unchecked Sendable {
    let update: @Sendable (String, Double) -> Void
    let failure: @Sendable (String) -> Void
    init(update: @escaping @Sendable (String, Double) -> Void, failure: @escaping @Sendable (String) -> Void) {
        self.update = update
        self.failure = failure
    }

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult,
              let detection = result.classifications.first else { return }
        update(detection.identifier, detection.confidence)
    }

    func request(_ request: SNRequest, didFailWithError error: Error) { failure(error.localizedDescription) }
    func requestDidComplete(_ request: SNRequest) {}
}

@MainActor
@Observable
private final class SoundGame {
    var status = "開始を押すとマイクがオンになります。"
    var running = false
    var claps = 0
    var laughs = 0
    var burst: Date?
    var dance: Date?
    private let engine = AVAudioEngine()
    private var analyzer: SNAudioStreamAnalyzer?
    private var observer: SoundObserver?
    private var listening = false
    private var generation = UUID()
    private var previous: Date = .distantPast

    func start() async {
        guard !running else { return }
        generation = UUID()
        let id = generation
        running = true
        status = "マイクを準備中…"
        guard await AVAudioApplication.requestRecordPermission() else {
            if generation == id { stop(message: "設定でマイクへのアクセスを許可してください。") }
            return
        }
        guard generation == id else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement)
            try session.setActive(true)
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                throw DemoError.unavailable("マイク入力を利用できません。")
            }
            let analyzer = SNAudioStreamAnalyzer(format: format)
            let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
            request.windowDuration = CMTime(seconds: 1, preferredTimescale: 1000)
            request.overlapFactor = 0.75
            let observer = SoundObserver { [weak self] identifier, confidence in
                Task { @MainActor in
                    guard let self, self.generation == id else { return }
                    self.handle(identifier, confidence: confidence)
                }
            } failure: { [weak self] error in
                Task { @MainActor in
                    guard let self, self.generation == id else { return }
                    self.stop(message: error)
                }
            }
            try analyzer.add(request, withObserver: observer)
            self.analyzer = analyzer
            self.observer = observer
            let queue = DispatchQueue(label: "lab.sound-analysis")
            // AVAudioEngine invokes this on its audio thread. Explicit Sendable
            // prevents the callback from inheriting SoundGame's MainActor.
            input.installTap(onBus: 0, bufferSize: 4096, format: format) { @Sendable buffer, time in
                queue.async { analyzer.analyze(buffer, atAudioFramePosition: time.sampleTime) }
            }
            listening = true
            try engine.start()
            status = "聞き取り中 · 拍手か笑い声を試してください"
        } catch {
            stop(message: error.localizedDescription)
        }
    }

    func stop(message: String = "停止中") {
        guard running else { return }
        generation = UUID()
        engine.stop()
        if listening { engine.inputNode.removeTap(onBus: 0) }
        listening = false
        analyzer = nil
        observer = nil
        running = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        status = message
    }

    private func handle(_ identifier: String, confidence: Double) {
        let isClap = identifier.contains("clap") || identifier.contains("applause")
        let isLaugh = identifier.contains("laugh") || identifier.contains("giggle") || identifier.contains("chuckle")
        guard confidence >= 0.28, isClap || isLaugh else { return }
        let now = Date()
        guard now.timeIntervalSince(previous) > 0.95 else { return }
        previous = now
        status = "\(identifier) · \(confidence.formatted(.percent.precision(.fractionLength(0))))"
        if isClap { claps += 1; burst = now }
        if isLaugh { laughs += 1; dance = now }
    }
}

struct SoundDemo: View {
    @State private var game = SoundGame()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        DemoScreen(title: "拍手で花火", instruction: "マイクをオンにして数回拍手すると花火。笑うと画面のロボットが踊ります。") {
            TimelineView(.animation(paused: !game.running)) { timeline in
                let danceTime = game.dance.map { timeline.date.timeIntervalSince($0) } ?? 10
                ZStack {
                    RoundedRectangle(cornerRadius: 18).fill(.indigo.gradient)
                    Canvas { context, size in
                        guard let burst = game.burst else { return }
                        let time = max(0, timeline.date.timeIntervalSince(burst))
                        guard time < 1.1 else { return }
                        for index in 0..<36 {
                            let angle = Double(index) * .pi / 18
                            let speed = Double(65 + (index * 17 % 85))
                            let x = size.width * 0.5 + cos(angle) * speed * time
                            let y = size.height * 0.39 + sin(angle) * speed * time + 46 * time * time
                            let color = Color(hue: Double(index % 7) / 7, saturation: 0.7, brightness: 1)
                            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 8, height: 8)),
                                         with: .color(color.opacity(1 - time / 1.1)))
                        }
                    }
                    Text("🤖").font(.system(size: 72))
                        .rotationEffect(.degrees(danceTime < 1.5 ? sin(danceTime * 22) * 24 : 0))
                        .offset(y: danceTime < 1.5 ? -abs(sin(danceTime * 11)) * 40 : 0)
                }
                .clipShape(.rect(cornerRadius: 18))
            }
            HStack {
                Label("拍手 \(game.claps)", systemImage: "hands.clap")
                Spacer()
                Label("笑い声 \(game.laughs)", systemImage: "face.smiling")
            }
            DemoStatus(message: game.status)
            Button(game.running ? "停止" : "マイクをオン", systemImage: game.running ? "stop.fill" : "mic.fill") {
                if game.running { game.stop() } else { Task { await game.start() } }
            }
            .buttonStyle(.borderedProminent)
        }
        .onDisappear { game.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { game.stop() }
        }
    }
}

@MainActor
@Observable
private final class MarblePhysics {
    var position = CGPoint(x: 0.5, y: 0.5)
    var impact = 0.0
    var status = "iPhoneを傾けてみてください。"
    var hapticsOn = true
    var soundOn = true

    private let motion = CMMotionManager()
    private var hapticEngine: CHHapticEngine?
    private var audio: AVAudioPlayer?
    private var velocity = CGVector.zero
    private var former: Date?
    private var lastImpact: Date = .distantPast

    func start() {
        former = nil
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { status = error.localizedDescription }
        guard motion.isDeviceMotionAvailable else {
            status = "iPhone実機を傾けると動きます。「弱い／強い衝突」はタップで試せます。"
            return
        }
        motion.deviceMotionUpdateInterval = 1 / 60
        motion.startDeviceMotionUpdates()
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        hapticEngine?.stop(completionHandler: nil)
        hapticEngine = nil
        audio?.stop()
        audio = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func step(at time: Date, bounds: CGSize) {
        defer { former = time }
        guard let former, bounds.width > 64, bounds.height > 64, let gravity = motion.deviceMotion?.gravity else { return }
        let dt = min(0.04, max(0, time.timeIntervalSince(former)))
        velocity.dx = (velocity.dx + gravity.x * dt * 1.8) * 0.987
        velocity.dy = (velocity.dy - gravity.y * dt * 1.8) * 0.987
        let x = position.x + velocity.dx * dt
        let y = position.y + velocity.dy * dt
        let left = 25 / bounds.width
        let top = 25 / bounds.height
        var speed = 0.0
        if x < left || x > 1 - left {
            speed = abs(velocity.dx)
            velocity.dx *= -0.66
        }
        if y < top || y > 1 - top {
            speed = max(speed, abs(velocity.dy))
            velocity.dy *= -0.66
        }
        position = CGPoint(x: max(left, min(1 - left, x)), y: max(top, min(1 - top, y)))
        if speed > 0.085 && time.timeIntervalSince(lastImpact) > 0.065 {
            collision(strength: min(1, speed / 0.95))
            lastImpact = time
        }
    }

    func collision(strength: Double) {
        impact = strength
        if hapticsOn && CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            do {
                if hapticEngine == nil {
                    let engine = try CHHapticEngine()
                    engine.playsHapticsOnly = true
                    hapticEngine = engine
                }
                if let engine = hapticEngine {
                    try engine.start()
                    let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
                        .init(parameterID: .hapticIntensity, value: Float(strength)),
                        .init(parameterID: .hapticSharpness, value: Float(0.20 + strength * 0.75))
                    ], relativeTime: 0)
                    let pattern = try CHHapticPattern(events: [event], parameters: [])
                    try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
                }
            } catch { hapticEngine = nil }
        }
        if soundOn {
            if audio == nil, let url = Bundle.main.url(forResource: "MarbleHit", withExtension: "wav") {
                audio = try? AVAudioPlayer(contentsOf: url)
                audio?.enableRate = true
            }
            audio?.currentTime = 0
            audio?.volume = Float(strength)
            audio?.rate = Float(0.75 + 0.5 * strength)
            audio?.play()
        }
    }
}

struct MarbleDemo: View {
    @State private var physics = MarblePhysics()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var physics = physics
        DemoScreen(title: "ビー玉の手触り", instruction: "iPhoneを傾けてビー玉を転がします。そっと壁に当てたときと、勢いよく当てたときの音と振動を比べてください。") {
            GeometryReader { proxy in
                TimelineView(.animation(paused: scenePhase != .active)) { timeline in
                    ZStack {
                        RoundedRectangle(cornerRadius: 22).fill(.indigo.opacity(0.13))
                        RoundedRectangle(cornerRadius: 22).strokeBorder(.indigo.opacity(0.35), lineWidth: 4)
                        Circle().fill(.radialGradient(colors: [.white, .cyan, .indigo],
                                                      center: .topLeading, startRadius: 0, endRadius: 49))
                            .frame(width: 48, height: 48)
                            .shadow(color: .indigo.opacity(0.35), radius: 6, x: 2, y: 4)
                            .position(x: physics.position.x * proxy.size.width, y: physics.position.y * proxy.size.height)
                    }
                    .onChange(of: timeline.date) { _, now in physics.step(at: now, bounds: proxy.size) }
                }
            }
            .accessibilityHidden(true)
            ProgressView(value: physics.impact) { Text("衝突の強さ") }
            HStack {
                Button("弱い衝突") { physics.collision(strength: 0.2) }.buttonStyle(.bordered)
                Button("強い衝突") { physics.collision(strength: 1) }.buttonStyle(.bordered)
            }
            HStack {
                Toggle("振動", isOn: $physics.hapticsOn)
                Toggle("音", isOn: $physics.soundOn)
            }
            .font(.footnote)
            DemoStatus(message: physics.status)
        }
        .onAppear { physics.start() }
        .onDisappear { physics.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { physics.stop() }
            if phase == .active { physics.start() }
        }
    }
}
