@preconcurrency import MultipeerConnectivity
@preconcurrency import NearbyInteraction
import SwiftUI
import simd

@MainActor
@Observable
private final class TreasureFinder: NSObject {
    var status = "2台のiPhoneでこの画面を開いてください。"
    var peers: [MCPeerID] = []
    var invitation: MCPeerID?
    var distance: Float?
    var direction: simd_float3?
    var active = false
    private var peer: MCPeerID?
    private var connection: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var ranging: NISession?
    private var invitationHandler: ((Bool, MCSession?) -> Void)?
    private var connectedPeer: MCPeerID?

    var supported: Bool { NISession.deviceCapabilities.supportsPreciseDistanceMeasurement }

    func start() {
        guard !active else { return }
        guard supported else { status = "UWBに対応するiPhone実機が必要です。"; return }
        active = true
        let peer = MCPeerID(displayName: String(UIDevice.current.name.prefix(48)))
        self.peer = peer
        let connection = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        connection.delegate = self
        self.connection = connection
        let ranging = NISession()
        ranging.delegate = self
        self.ranging = ranging
        let advertiser = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: nil, serviceType: "ailab-find")
        advertiser.delegate = self
        self.advertiser = advertiser
        let browser = MCNearbyServiceBrowser(peer: peer, serviceType: "ailab-find")
        browser.delegate = self
        self.browser = browser
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        status = "近くのiPhoneを探しています。もう1台でも「端末を探す」を押してください。"
    }

    func invite(_ peer: MCPeerID) {
        guard let connection else { return }
        browser?.invitePeer(peer, to: connection, withContext: nil, timeout: 25)
        status = "相手のiPhoneで接続を許可してください。"
    }

    func answer(_ accept: Bool) {
        invitationHandler?(accept, accept ? connection : nil)
        invitationHandler = nil
        invitation = nil
    }

    func stop() {
        active = false
        answer(false)
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        connection?.disconnect()
        ranging?.invalidate()
        advertiser = nil
        browser = nil
        connection = nil
        ranging = nil
        connectedPeer = nil
        peers = []
        distance = nil
        direction = nil
        status = "停止しました。"
    }

    private func sendToken() {
        guard let token = ranging?.discoveryToken, let connection, !connection.connectedPeers.isEmpty else { return }
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            try connection.send(data, toPeers: connection.connectedPeers, with: .reliable)
        } catch { status = error.localizedDescription }
    }
}

extension TreasureFinder: @preconcurrency MCNearbyServiceBrowserDelegate, @preconcurrency MCNearbyServiceAdvertiserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard self.browser === browser, !peers.contains(peerID) else { return }
        peers.append(peerID)
        status = "相手の名前をタップして接続してください。"
    }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        guard self.browser === browser else { return }
        peers.removeAll { $0 == peerID }
    }
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) { status = error.localizedDescription }
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) { status = error.localizedDescription }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        guard self.advertiser === advertiser, invitation == nil, connectedPeer == nil else {
            invitationHandler(false, nil)
            return
        }
        invitation = peerID
        self.invitationHandler = invitationHandler
    }
}

extension TreasureFinder: @preconcurrency MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        guard session === connection else { return }
        switch state {
        case .connected:
            connectedPeer = peerID
            advertiser?.stopAdvertisingPeer()
            browser?.stopBrowsingForPeers()
            status = "接続しました。両方のiPhoneの上側を相手に向けてください。"
            sendToken()
        case .notConnected:
            if connectedPeer == peerID {
                connectedPeer = nil
                distance = nil
                direction = nil
                status = "接続が切れました。停止して、もう一度探してください。"
            }
        case .connecting: status = "接続中…"
        @unknown default: break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard session === connection else { return }
        do {
            guard let token = try NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) else { return }
            let configuration = NINearbyPeerConfiguration(peerToken: token)
            ranging?.run(configuration)
        } catch { status = error.localizedDescription }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension TreasureFinder: @preconcurrency NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard session === ranging else { return }
        guard let object = nearbyObjects.first else { return }
        distance = object.distance
        direction = object.direction
        status = direction == nil ? "距離を測定中。相手へiPhoneの上側を向けると方向が表示されます。" : "矢印の先に相手のiPhoneがあります。"
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        guard session === ranging else { return }
        distance = nil
        direction = nil
        status = error.localizedDescription + " 停止してから再接続してください。"
    }

    func sessionWasSuspended(_ session: NISession) {
        distance = nil
        direction = nil
        status = "測距が中断しました。両方のiPhoneでアプリを開いてください。"
    }

    func sessionSuspensionEnded(_ session: NISession) {
        guard session === ranging, let configuration = session.configuration else { return }
        session.run(configuration)
    }

    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        distance = nil
        direction = nil
        status = "相手を見失いました。近づいて、両方のアプリを開いてください。"
        if reason == .timeout, let configuration = session.configuration { session.run(configuration) }
    }
}

struct TreasureDemo: View {
    @State private var finder = TreasureFinder()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        DemoScreen(title: "iPhoneで宝探し", instruction: "2台で「端末を探す」を押し、片方で相手の名前を選択。接続後は片方を隠し、もう片方の距離と矢印で探します。両方の画面を開いたままにしてください。") {
            if let direction = finder.direction {
                Image(systemName: "arrow.up")
                    .font(.system(size: 90, weight: .bold))
                    .foregroundStyle(.indigo)
                    .rotationEffect(.radians(Double(atan2(direction.x, -direction.z))))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("相手の方向")
                if abs(direction.y) > 0.3 {
                    Text(direction.y > 0 ? "相手は上の方" : "相手は下の方").foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "location.viewfinder")
                    .font(.system(size: 72, weight: .light))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(.secondary)
            }
            if let distance = finder.distance {
                Text("\(distance.formatted(.number.precision(.fractionLength(2)))) m")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
            }
            ForEach(finder.peers, id: \.self) { peer in
                Button(peer.displayName) { finder.invite(peer) }.buttonStyle(.bordered)
            }
            DemoStatus(message: finder.status)
            Button(finder.active ? "停止" : "端末を探す", systemImage: finder.active ? "stop.fill" : "magnifyingglass") {
                if finder.active { finder.stop() } else { finder.start() }
            }
            .buttonStyle(.borderedProminent)
        }
        .alert("近くのiPhoneから接続", isPresented: Binding(get: { finder.invitation != nil }, set: { if !$0 { finder.answer(false) } })) {
            Button("接続する") { finder.answer(true) }
            Button("キャンセル", role: .cancel) { finder.answer(false) }
        } message: {
            Text("\(finder.invitation?.displayName ?? "") と距離・方向を共有します。")
        }
        .onDisappear { finder.stop() }
        .onChange(of: scenePhase) { _, phase in if phase == .background { finder.stop() } }
    }
}
