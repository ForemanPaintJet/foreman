//
//  WebRTCClient.swift
//  foreman
//
//  Created by Jed Lu on 2025/7/4.
//

import AVFoundation
import Combine
import ComposableArchitecture
import Foundation
import WebRTC

// MARK: - WebRTC Models

struct VideoTrackInfo: Equatable, Identifiable {
    let id: String
    let userId: String
    let track: RTCVideoTrack?

    static func == (lhs: VideoTrackInfo, rhs: VideoTrackInfo) -> Bool {
        lhs.id == rhs.id && lhs.userId == rhs.userId
    }
}

struct PeerConnectionInfo: Equatable {
    let userId: String
    let connectionState: RTCPeerConnectionState
}

// MARK: - WebRTC Client

@MainActor
class WebRTCClient: NSObject, ObservableObject {
    @Published var remoteVideoTracks: [VideoTrackInfo] = []
    @Published var peerConnections: [String: RTCPeerConnection] = [:]
    @Published var connectionStates: [PeerConnectionInfo] = []

    private var peerConnectionFactory: RTCPeerConnectionFactory!
    private var peerConnectionDelegates: [String: PeerConnectionDelegate] = [:]

    // ICE servers configuration
    private let iceServers = [
        RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
        RTCIceServer(urlStrings: ["stun:stun1.l.google.com:19302"]),
        RTCIceServer(urlStrings: ["stun:stun2.l.google.com:19302"]),
        RTCIceServer(urlStrings: ["stun:stun3.l.google.com:19302"]),
    ]

    // Subjects for signaling
    let offerSubject = PassthroughSubject<WebRTCOffer, Never>()
    let answerSubject = PassthroughSubject<WebRTCAnswer, Never>()
    let iceCandidateSubject = PassthroughSubject<ICECandidate, Never>()

    override init() {
        super.init()
        setupWebRTC()
    }

    private func setupWebRTC() {
        print("🎥 WebRTCClient: Setting up WebRTC")

        // Initialize peer connection factory
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        peerConnectionFactory = RTCPeerConnectionFactory(
            encoderFactory: encoderFactory,
            decoderFactory: decoderFactory
        )

        setupLocalMedia()
    }

    private func setupLocalMedia() {
        print("🎥 WebRTCClient: Setting up receive-only mode (no local media)")

        // For receive-only mode, we don't need to set up local camera/microphone
        // We'll only handle incoming video/audio streams from other clients

        // Note: Adding a minimal audio transceiver to help with ICE negotiation
        // This is sometimes needed for proper WebRTC negotiation in receive-only mode
    }

    func toggleAudio() {
        print("🔊 WebRTCClient: Audio controls disabled - receive-only mode")
    }

    func toggleVideo() {
        print("🎥 WebRTCClient: Video controls disabled - receive-only mode")
    }

    func switchCamera() {
        print("📷 WebRTCClient: Camera controls disabled - receive-only mode")
    }

    // MARK: - Peer Connection Management

    func createPeerConnection(for userId: String) -> RTCPeerConnection? {
        print("🤝 WebRTCClient: Creating peer connection for user: \(userId)")
        print("🤝 WebRTCClient: Current peer connections: \(peerConnections.keys.sorted())")

        let configuration = RTCConfiguration()
        configuration.iceServers = iceServers
        configuration.sdpSemantics = .unifiedPlan
        configuration.continualGatheringPolicy = .gatherContinually
        configuration.iceTransportPolicy = .all
        configuration.bundlePolicy = .balanced
        configuration.rtcpMuxPolicy = .require

        print("🤝 WebRTCClient: ICE servers configured: \(iceServers.count)")

        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)

        guard
            let peerConnection = peerConnectionFactory.peerConnection(
                with: configuration, constraints: constraints, delegate: nil)
        else {
            print("❌ WebRTCClient: Failed to create peer connection for \(userId)")
            return nil
        }

        print("✅ WebRTCClient: RTCPeerConnection created successfully for \(userId)")

        // Set delegate and store it to prevent deallocation
        let delegate = PeerConnectionDelegate(userId: userId, webRTCClient: self)
        peerConnection.delegate = delegate
        peerConnectionDelegates[userId] = delegate
        print("✅ WebRTCClient: Delegate set and stored for peer connection \(userId)")

        // For receive-only mode, we add transceivers to receive audio and video
        // This helps with proper ICE negotiation
        let audioTransceiverInit = RTCRtpTransceiverInit()
        audioTransceiverInit.direction = .recvOnly
        peerConnection.addTransceiver(of: .audio, init: audioTransceiverInit)
        print("🎵 WebRTCClient: Audio receive-only transceiver added for \(userId)")

        let videoTransceiverInit = RTCRtpTransceiverInit()
        videoTransceiverInit.direction = .recvOnly
        peerConnection.addTransceiver(of: .video, init: videoTransceiverInit)
        print("🎥 WebRTCClient: Video receive-only transceiver added for \(userId)")

        peerConnections[userId] = peerConnection

        updateConnectionState(for: userId, state: peerConnection.connectionState)

        print("✅ WebRTCClient: Receive-only peer connection created for \(userId)")
        print("🧊 WebRTCClient: ICE gathering state: \(peerConnection.iceGatheringState.rawValue)")
        print("🧊 WebRTCClient: ICE connection state: \(peerConnection.iceConnectionState.rawValue)")
        print("🤝 WebRTCClient: Total peer connections: \(peerConnections.count)")
        return peerConnection
    }

    func removePeerConnection(for userId: String) {
        print("🗑️ WebRTCClient: Removing peer connection for user: \(userId)")

        if let peerConnection = peerConnections[userId] {
            peerConnection.close()
            peerConnections.removeValue(forKey: userId)
        }

        // Remove the stored delegate
        peerConnectionDelegates.removeValue(forKey: userId)

        // Remove remote video tracks for this user
        remoteVideoTracks.removeAll { $0.userId == userId }
        connectionStates.removeAll { $0.userId == userId }

        print("✅ WebRTCClient: Peer connection and delegate removed for \(userId)")
    }

    func createOffer(for userId: String) async throws {
        guard let peerConnection = peerConnections[userId] else {
            throw WebRTCError.peerConnectionNotFound
        }

        print("📞 WebRTCClient: Creating offer for \(userId)")

        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)

        do {
            let offer = try await peerConnection.offer(for: constraints)
            try await peerConnection.setLocalDescription(offer)

            let webRTCOffer = WebRTCOffer(
                sdp: offer.sdp,
                type: "offer",
                from: "self",  // You might want to use actual user ID
                to: userId
            )

            offerSubject.send(webRTCOffer)
            print("✅ WebRTCClient: Offer created and sent for \(userId)")
        } catch {
            print("❌ WebRTCClient: Failed to create offer for \(userId): \(error)")
            throw error
        }
    }

    func handleRemoteOffer(_ offer: WebRTCOffer) async throws {
        let userId = offer.from

        print("📞 WebRTCClient: Handling remote offer from \(userId)")
        print("📞 WebRTCClient: Offer SDP length: \(offer.sdp.count)")
        print(
            "📞 WebRTCClient: Current peer connections before handling: \(peerConnections.keys.sorted())"
        )

        if peerConnections[userId] == nil {
            print("📞 WebRTCClient: No existing peer connection for \(userId), creating new one")
            let created = createPeerConnection(for: userId)
            if created == nil {
                print("❌ WebRTCClient: Failed to create peer connection for \(userId)")
                throw WebRTCError.peerConnectionNotFound
            }
        } else {
            print("📞 WebRTCClient: Using existing peer connection for \(userId)")
        }

        guard let peerConnection = peerConnections[userId] else {
            print("❌ WebRTCClient: Peer connection still nil after creation attempt for \(userId)")
            throw WebRTCError.peerConnectionNotFound
        }

        print(
            "📞 WebRTCClient: Peer connection found for \(userId), state: \(peerConnection.connectionState)"
        )

        let remoteDescription = RTCSessionDescription(type: .offer, sdp: offer.sdp)

        do {
            print("🔄 WebRTCClient: Setting remote description (offer) for \(userId)")
            try await peerConnection.setRemoteDescription(remoteDescription)
            print("✅ WebRTCClient: Remote description set for \(userId)")

            let constraints = RTCMediaConstraints(
                mandatoryConstraints: nil, optionalConstraints: nil)
            print("🔄 WebRTCClient: Creating answer for \(userId)")
            let answer = try await peerConnection.answer(for: constraints)
            print("✅ WebRTCClient: Answer created for \(userId)")

            print("🔄 WebRTCClient: Setting local description (answer) for \(userId)")
            try await peerConnection.setLocalDescription(answer)
            print("✅ WebRTCClient: Local description set for \(userId)")
            print(
                "🧊 WebRTCClient: ICE gathering state after setting local description: \(peerConnection.iceGatheringState.rawValue)"
            )
            print(
                "🧊 WebRTCClient: ICE connection state after setting local description: \(peerConnection.iceConnectionState.rawValue)"
            )

            let webRTCAnswer = WebRTCAnswer(
                sdp: answer.sdp,
                type: "answer",
                from: "self",  // You might want to use actual user ID
                to: userId
            )

            answerSubject.send(webRTCAnswer)
            print("✅ WebRTCClient: Answer created and sent for \(userId)")

            // Add a small delay to allow ICE gathering to start
            Task {
                try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
                print(
                    "🧊 WebRTCClient: ICE gathering state after 1s: \(peerConnection.iceGatheringState.rawValue)"
                )
                print(
                    "🧊 WebRTCClient: ICE connection state after 1s: \(peerConnection.iceConnectionState.rawValue)"
                )
            }
        } catch {
            print("❌ WebRTCClient: Failed to handle remote offer from \(userId): \(error)")
            throw error
        }
    }

    func handleRemoteAnswer(_ answer: WebRTCAnswer) async throws {
        let userId = answer.from

        print("📞 WebRTCClient: Handling remote answer from \(userId)")

        guard let peerConnection = peerConnections[userId] else {
            throw WebRTCError.peerConnectionNotFound
        }

        let remoteDescription = RTCSessionDescription(type: .answer, sdp: answer.sdp)

        do {
            try await peerConnection.setRemoteDescription(remoteDescription)
            print("✅ WebRTCClient: Remote answer set for \(userId)")
        } catch {
            print("❌ WebRTCClient: Failed to handle remote answer from \(userId): \(error)")
            throw error
        }
    }

    func handleRemoteIceCandidate(_ candidate: ICECandidate) async throws {
        let userId = candidate.from

        print("🧊 WebRTCClient: Handling ICE candidate from \(userId)")

        guard let peerConnection = peerConnections[userId] else {
            throw WebRTCError.peerConnectionNotFound
        }

        let iceCandidate = RTCIceCandidate(
            sdp: candidate.candidate,
            sdpMLineIndex: Int32(candidate.sdpMLineIndex),
            sdpMid: candidate.sdpMid
        )

        do {
            try await peerConnection.add(iceCandidate)
            print("✅ WebRTCClient: ICE candidate added for \(userId)")
        } catch {
            print("❌ WebRTCClient: Failed to add ICE candidate for \(userId): \(error)")
            throw error
        }
    }

    // MARK: - Internal Methods

    func addRemoteVideoTrack(_ track: RTCVideoTrack, for userId: String) {
        print("📺 WebRTCClient: Adding remote video track for \(userId)")
        print(
            "📺 WebRTCClient: Video track state - isEnabled: \(track.isEnabled), readyState: \(track.readyState)"
        )

        let videoTrackInfo = VideoTrackInfo(
            id: UUID().uuidString,
            userId: userId,
            track: track
        )

        remoteVideoTracks.append(videoTrackInfo)
        print(
            "✅ WebRTCClient: Added remote video track for \(userId) - Total tracks: \(remoteVideoTracks.count)"
        )

        // Log all current video tracks
        for (index, trackInfo) in remoteVideoTracks.enumerated() {
            print(
                "📺 Track \(index): User \(trackInfo.userId), Enabled: \(trackInfo.track?.isEnabled ?? false)"
            )
        }
    }

    func updateConnectionState(for userId: String, state: RTCPeerConnectionState) {
        if let index = connectionStates.firstIndex(where: { $0.userId == userId }) {
            connectionStates[index] = PeerConnectionInfo(userId: userId, connectionState: state)
        } else {
            connectionStates.append(PeerConnectionInfo(userId: userId, connectionState: state))
        }

        print("🔗 WebRTCClient: Connection state for \(userId): \(state)")
    }

    func handleIceCandidate(_ candidate: RTCIceCandidate, for userId: String) {
        print("🧊 WebRTCClient: Processing ICE candidate for \(userId)")
        print("🧊 WebRTCClient: Candidate details - SDP: \(candidate.sdp)")
        print(
            "🧊 WebRTCClient: Candidate details - M-Line: \(candidate.sdpMLineIndex), MID: \(candidate.sdpMid ?? "nil")"
        )

        let iceCandidate = ICECandidate(
            candidate: candidate.sdp,
            sdpMLineIndex: Int(candidate.sdpMLineIndex),
            sdpMid: candidate.sdpMid,
            from: "self",  // You might want to use actual user ID
            to: userId
        )

        iceCandidateSubject.send(iceCandidate)
        print("🧊 WebRTCClient: ICE candidate sent to signaling for \(userId)")
    }
}

// MARK: - Peer Connection Delegate

class PeerConnectionDelegate: NSObject, RTCPeerConnectionDelegate {
    private let userId: String
    private weak var webRTCClient: WebRTCClient?

    init(userId: String, webRTCClient: WebRTCClient) {
        self.userId = userId
        self.webRTCClient = webRTCClient
        super.init()
    }

    func peerConnection(
        _ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState
    ) {
        print("🔗 PeerConnection[\(userId)]: Signaling state changed to \(stateChanged)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print(
            "📺 PeerConnection[\(userId)]: Stream added with \(stream.audioTracks.count) audio tracks and \(stream.videoTracks.count) video tracks"
        )

        // Log audio tracks
        for (index, audioTrack) in stream.audioTracks.enumerated() {
            print(
                "🔊 Audio track \(index): enabled=\(audioTrack.isEnabled), state=\(audioTrack.readyState)"
            )
        }

        // Log video tracks
        for (index, videoTrack) in stream.videoTracks.enumerated() {
            print(
                "📺 Video track \(index): enabled=\(videoTrack.isEnabled), state=\(videoTrack.readyState)"
            )
        }

        if let videoTrack = stream.videoTracks.first {
            print("📺 PeerConnection[\(userId)]: Adding first video track to WebRTC client")
            Task { @MainActor in
                webRTCClient?.addRemoteVideoTrack(videoTrack, for: userId)
            }
        } else {
            print("⚠️ PeerConnection[\(userId)]: No video tracks found in stream")
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("📺 PeerConnection[\(userId)]: Stream removed")

        Task { @MainActor in
            webRTCClient?.remoteVideoTracks.removeAll { $0.userId == userId }
        }
    }

    // MARK: - Modern Track-based Delegate Methods

    func peerConnection(
        _ peerConnection: RTCPeerConnection, didAdd receiver: RTCRtpReceiver,
        streams: [RTCMediaStream]
    ) {
        print("📺 PeerConnection[\(userId)]: Modern track added via receiver")
        print("📺 PeerConnection[\(userId)]: Track kind: \(receiver.track?.kind ?? "unknown")")
        print("📺 PeerConnection[\(userId)]: Track enabled: \(receiver.track?.isEnabled ?? false)")
        print("📺 PeerConnection[\(userId)]: Streams count: \(streams.count)")

        if let track = receiver.track, track.kind == "video",
            let videoTrack = track as? RTCVideoTrack
        {
            print(
                "📺 PeerConnection[\(userId)]: Modern video track received - adding to WebRTC client"
            )
            Task { @MainActor in
                webRTCClient?.addRemoteVideoTrack(videoTrack, for: userId)
            }
        } else if let track = receiver.track, track.kind == "audio" {
            print("🔊 PeerConnection[\(userId)]: Modern audio track received")
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove receiver: RTCRtpReceiver) {
        print("📺 PeerConnection[\(userId)]: Modern track removed via receiver")

        if let track = receiver.track, track.kind == "video" {
            Task { @MainActor in
                webRTCClient?.remoteVideoTracks.removeAll { $0.userId == userId }
            }
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate)
    {
        print("🧊 PeerConnection[\(userId)]: ICE candidate generated")
        print("🧊 PeerConnection[\(userId)]: Candidate SDP: \(candidate.sdp)")
        print("🧊 PeerConnection[\(userId)]: SDP M-Line Index: \(candidate.sdpMLineIndex)")
        print("🧊 PeerConnection[\(userId)]: SDP MID: \(candidate.sdpMid ?? "nil")")

        Task { @MainActor in
            webRTCClient?.handleIceCandidate(candidate, for: userId)
        }
    }

    func peerConnection(
        _ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]
    ) {
        print("🧊 PeerConnection[\(userId)]: ICE candidates removed")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("📡 PeerConnection[\(userId)]: Data channel opened")
    }

    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("🔄 PeerConnection[\(userId)]: Should negotiate")
    }

    func peerConnection(
        _ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState
    ) {
        print("🧊 PeerConnection[\(userId)]: ICE connection state changed to \(newState)")
    }

    func peerConnection(
        _ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState
    ) {
        print("🧊 PeerConnection[\(userId)]: ICE gathering state changed to \(newState)")
    }

    func peerConnection(
        _ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState
    ) {
        print("🔗 PeerConnection[\(userId)]: Peer connection state changed to \(newState)")

        Task { @MainActor in
            webRTCClient?.updateConnectionState(for: userId, state: newState)
        }
    }
}

// MARK: - WebRTC Errors

enum WebRTCError: Error, LocalizedError {
    case peerConnectionNotFound
    case failedToCreateOffer
    case failedToCreateAnswer
    case failedToSetDescription
    case failedToAddCandidate

    var errorDescription: String? {
        switch self {
        case .peerConnectionNotFound:
            return "Peer connection not found"
        case .failedToCreateOffer:
            return "Failed to create offer"
        case .failedToCreateAnswer:
            return "Failed to create answer"
        case .failedToSetDescription:
            return "Failed to set session description"
        case .failedToAddCandidate:
            return "Failed to add ICE candidate"
        }
    }
}

// MARK: - TCA Dependency

struct WebRTCClientDependency {
    var createPeerConnection: @Sendable (String) async -> Bool
    var removePeerConnection: @Sendable (String) async -> Void
    var createOffer: @Sendable (String) async throws -> Void
    var handleRemoteOffer: @Sendable (WebRTCOffer) async throws -> Void
    var handleRemoteAnswer: @Sendable (WebRTCAnswer) async throws -> Void
    var handleRemoteIceCandidate: @Sendable (ICECandidate) async throws -> Void
    var toggleAudio: @Sendable () -> Void
    var toggleVideo: @Sendable () -> Void
    var switchCamera: @Sendable () -> Void
    var offerStream: @Sendable () -> AsyncStream<WebRTCOffer>
    var answerStream: @Sendable () -> AsyncStream<WebRTCAnswer>
    var iceCandidateStream: @Sendable () -> AsyncStream<ICECandidate>
    var getClient: @Sendable () async -> WebRTCClient
}

extension WebRTCClientDependency: DependencyKey {
    static let liveValue = WebRTCClientDependency(
        createPeerConnection: { userId in
            await MainActor.run {
                WebRTCClientLive.shared.createPeerConnection(for: userId) != nil
            }
        },
        removePeerConnection: { userId in
            await MainActor.run {
                WebRTCClientLive.shared.removePeerConnection(for: userId)
            }
        },
        createOffer: { userId in
            try await WebRTCClientLive.shared.createOffer(for: userId)
        },
        handleRemoteOffer: { offer in
            try await WebRTCClientLive.shared.handleRemoteOffer(offer)
        },
        handleRemoteAnswer: { answer in
            try await WebRTCClientLive.shared.handleRemoteAnswer(answer)
        },
        handleRemoteIceCandidate: { candidate in
            try await WebRTCClientLive.shared.handleRemoteIceCandidate(candidate)
        },
        toggleAudio: {
            //            WebRTCClientLive.shared.toggleAudio()
        },
        toggleVideo: {
            //            WebRTCClientLive.shared.toggleVideo()
        },
        switchCamera: {
            //            WebRTCClientLive.shared.switchCamera()
        },
        offerStream: {
            WebRTCClientLive.shared.offerStream
        },
        answerStream: {
            WebRTCClientLive.shared.answerStream
        },
        iceCandidateStream: {
            WebRTCClientLive.shared.iceCandidateStream
        },
        getClient: {
            await MainActor.run {
                WebRTCClientLive.shared.getClient()
            }
        }
    )
}

extension DependencyValues {
    var webRTCClient: WebRTCClientDependency {
        get { self[WebRTCClientDependency.self] }
        set { self[WebRTCClientDependency.self] = newValue }
    }
}

// MARK: - Live Implementation for TCA

@MainActor
class WebRTCClientLive {
    static let shared = WebRTCClientLive()

    private let webRTCClient = WebRTCClient()

    // Async streams for TCA
    let offerStream: AsyncStream<WebRTCOffer>
    let answerStream: AsyncStream<WebRTCAnswer>
    let iceCandidateStream: AsyncStream<ICECandidate>

    private let offerContinuation: AsyncStream<WebRTCOffer>.Continuation
    private let answerContinuation: AsyncStream<WebRTCAnswer>.Continuation
    private let iceCandidateContinuation: AsyncStream<ICECandidate>.Continuation

    private var cancellables = Set<AnyCancellable>()

    init() {
        let (offerStream, offerCont) = AsyncStream.makeStream(of: WebRTCOffer.self)
        let (answerStream, answerCont) = AsyncStream.makeStream(of: WebRTCAnswer.self)
        let (iceCandidateStream, iceCandidateCont) = AsyncStream.makeStream(of: ICECandidate.self)

        self.offerStream = offerStream
        self.answerStream = answerStream
        self.iceCandidateStream = iceCandidateStream

        self.offerContinuation = offerCont
        self.answerContinuation = answerCont
        self.iceCandidateContinuation = iceCandidateCont

        setupBindings()
    }

    private func setupBindings() {
        webRTCClient.offerSubject
            .sink { [weak self] offer in
                self?.offerContinuation.yield(offer)
            }
            .store(in: &cancellables)

        webRTCClient.answerSubject
            .sink { [weak self] answer in
                self?.answerContinuation.yield(answer)
            }
            .store(in: &cancellables)

        webRTCClient.iceCandidateSubject
            .sink { [weak self] candidate in
                self?.iceCandidateContinuation.yield(candidate)
            }
            .store(in: &cancellables)
    }

    func createPeerConnection(for userId: String) -> RTCPeerConnection? {
        webRTCClient.createPeerConnection(for: userId)
    }

    func removePeerConnection(for userId: String) {
        webRTCClient.removePeerConnection(for: userId)
    }

    func createOffer(for userId: String) async throws {
        try await webRTCClient.createOffer(for: userId)
    }

    func handleRemoteOffer(_ offer: WebRTCOffer) async throws {
        try await webRTCClient.handleRemoteOffer(offer)
    }

    func handleRemoteAnswer(_ answer: WebRTCAnswer) async throws {
        try await webRTCClient.handleRemoteAnswer(answer)
    }

    func handleRemoteIceCandidate(_ candidate: ICECandidate) async throws {
        try await webRTCClient.handleRemoteIceCandidate(candidate)
    }

    func getClient() -> WebRTCClient {
        return webRTCClient
    }
}
