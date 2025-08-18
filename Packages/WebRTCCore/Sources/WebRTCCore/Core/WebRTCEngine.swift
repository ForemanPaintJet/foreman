//
//  WebRTCEngine.swift
//  WebRTCCore
//
//  Created by Claude on 2025/8/18.
//

import Foundation
import OSLog
import WebRTC

// MARK: - WebRTC Engine

/// Core WebRTC engine that handles peer connections and media streams
/// This class is focused solely on WebRTC functionality, with no signaling logic
/// Uses AsyncStream for modern event handling instead of delegate pattern
@MainActor
public class WebRTCEngine: NSObject, ObservableObject {

  // MARK: - Public Properties

  /// Currently active video tracks from remote peers
  @Published public private(set) var remoteVideoTracks: [VideoTrackInfo] = []

  /// Current peer connection states
  @Published public private(set) var connectionStates: [PeerConnectionInfo] = []

  /// List of currently connected peer user IDs
  public var connectedPeers: [String] {
    Array(peerConnections.keys)
  }

  /// Current video tracks organized by user ID
  public var videoTracks: [VideoTrackInfo] {
    remoteVideoTracks
  }

  /// Event stream for WebRTC events (replaces delegate pattern)
  public let events: AsyncStream<WebRTCEvent>
  private let eventsContinuation: AsyncStream<WebRTCEvent>.Continuation

  // MARK: - Private Properties

  private var peerConnectionFactory: RTCPeerConnectionFactory!
  private var peerConnections: [String: RTCPeerConnection] = [:]
  private var peerConnectionDelegates: [String: PeerConnectionDelegate] = [:]

  private let logger = Logger(subsystem: "WebRTCCore", category: "WebRTCEngine")

  // ICE servers configuration
  private let iceServers = [
    RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
    RTCIceServer(urlStrings: ["stun:stun1.l.google.com:19302"]),
    RTCIceServer(urlStrings: ["stun:stun2.l.google.com:19302"]),
    RTCIceServer(urlStrings: ["stun:stun3.l.google.com:19302"]),
  ]

  // MARK: - Initialization

  public override init() {
    // Initialize event stream
    let (stream, continuation) = AsyncStream.makeStream(of: WebRTCEvent.self)
    self.events = stream
    self.eventsContinuation = continuation
    
    super.init()
    setupWebRTC()
    
    // Start internal event handling
    Task { @MainActor in
      for await event in self.events {
        self.handleWebRTCEvent(event)
      }
    }
  }

  // MARK: - Setup

  private func setupWebRTC() {
    logger.info("🎥 WebRTCEngine: Setting up WebRTC")

    let decoderFactory = RTCDefaultVideoDecoderFactory()
    let encoderFactory = RTCDefaultVideoEncoderFactory()

    peerConnectionFactory = RTCPeerConnectionFactory(
      encoderFactory: encoderFactory,
      decoderFactory: decoderFactory
    )

    guard peerConnectionFactory != nil else {
      logger.error("❌ WebRTCEngine: Failed to initialize peer connection factory")
      eventsContinuation.yield(.errorOccurred(error: .factoryInitializationFailed, userId: nil))
      return
    }

    logger.info("✅ WebRTCEngine: WebRTC setup completed (receive-only mode)")
  }

  // MARK: - Public API

  /// Create a new peer connection for the specified user
  /// - Parameter userId: The user ID to create connection for
  /// - Returns: True if connection was created successfully, false otherwise
  @discardableResult
  public func createPeerConnection(for userId: String) -> Bool {
    logger.info("🤝 WebRTCEngine: Creating peer connection for user: \(userId)")

    guard peerConnections[userId] == nil else {
      logger.warning("⚠️ WebRTCEngine: Peer connection for \(userId) already exists")
      return true
    }

    let configuration = RTCConfiguration()
    configuration.iceServers = iceServers
    configuration.sdpSemantics = .unifiedPlan
    configuration.continualGatheringPolicy = .gatherContinually
    configuration.iceTransportPolicy = .all
    configuration.bundlePolicy = .balanced
    configuration.rtcpMuxPolicy = .require

    let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)

    guard
      let peerConnection = peerConnectionFactory.peerConnection(
        with: configuration,
        constraints: constraints,
        delegate: nil
      )
    else {
      logger.error("❌ WebRTCEngine: Failed to create peer connection for \(userId)")
      eventsContinuation.yield(.errorOccurred(error: .peerConnectionNotFound, userId: userId))
      return false
    }

    // Set up delegate
    let delegate = PeerConnectionDelegate(userId: userId, eventsContinuation: eventsContinuation)
    peerConnection.delegate = delegate
    peerConnectionDelegates[userId] = delegate

    // Configure for receive-only mode
    let audioTransceiverInit = RTCRtpTransceiverInit()
    audioTransceiverInit.direction = .recvOnly
    peerConnection.addTransceiver(of: .audio, init: audioTransceiverInit)

    let videoTransceiverInit = RTCRtpTransceiverInit()
    videoTransceiverInit.direction = .recvOnly
    peerConnection.addTransceiver(of: .video, init: videoTransceiverInit)

    peerConnections[userId] = peerConnection
    updateConnectionState(for: userId, state: peerConnection.connectionState)

    logger.info("✅ WebRTCEngine: Peer connection created for \(userId)")
    return true
  }

  /// Remove a peer connection for the specified user
  /// - Parameter userId: The user ID to remove connection for
  public func removePeerConnection(for userId: String) {
    logger.info("🗑️ WebRTCEngine: Removing peer connection for user: \(userId)")

    if let peerConnection = peerConnections[userId] {
      peerConnection.close()
      peerConnections.removeValue(forKey: userId)
    }

    peerConnectionDelegates.removeValue(forKey: userId)
    remoteVideoTracks.removeAll { $0.userId == userId }
    connectionStates.removeAll { $0.userId == userId }

    eventsContinuation.yield(.videoTrackRemoved(userId: userId))

    logger.info("✅ WebRTCEngine: Peer connection removed for \(userId)")
  }

  /// Create an offer for the specified user
  /// - Parameter userId: The user ID to create offer for
  public func createOffer(for userId: String) async throws {
    guard let peerConnection = peerConnections[userId] else {
      logger.error("❌ WebRTCEngine: No peer connection found for \(userId)")
      throw WebRTCError.peerConnectionNotFound
    }

    logger.info("📞 WebRTCEngine: Creating offer for \(userId)")

    let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)

    do {
      let offer = try await peerConnection.offer(for: constraints)
      try await peerConnection.setLocalDescription(offer)

      // Send offer event
      eventsContinuation.yield(.offerGenerated(sdp: offer.sdp, userId: userId))

      logger.info("✅ WebRTCEngine: Offer created and local description set for \(userId)")
    } catch {
      logger.error("❌ WebRTCEngine: Failed to create offer for \(userId): \(error)")
      eventsContinuation.yield(.errorOccurred(error: .failedToCreateOffer, userId: userId))
      throw error
    }
  }

  /// Set remote offer and create answer
  /// - Parameters:
  ///   - offer: The remote SDP offer
  ///   - userId: The user ID this offer is from
  /// - Returns: The generated answer session description
  @discardableResult
  public func setRemoteOffer(_ offer: RTCSessionDescription, for userId: String) async throws
    -> RTCSessionDescription
  {
    // Create peer connection if it doesn't exist
    if peerConnections[userId] == nil {
      logger.info("📞 WebRTCEngine: No existing peer connection for \(userId), creating new one")
      guard createPeerConnection(for: userId) else {
        throw WebRTCError.peerConnectionNotFound
      }
    }

    guard let peerConnection = peerConnections[userId] else {
      logger.error("❌ WebRTCEngine: Failed to get peer connection for \(userId)")
      throw WebRTCError.peerConnectionNotFound
    }

    logger.info("📞 WebRTCEngine: Setting remote offer for \(userId)")

    do {
      try await peerConnection.setRemoteDescription(offer)
      logger.info("✅ WebRTCEngine: Remote offer set for \(userId)")

      let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
      let answer = try await peerConnection.answer(for: constraints)
      try await peerConnection.setLocalDescription(answer)

      // Send answer event
      eventsContinuation.yield(.answerGenerated(sdp: answer.sdp, userId: userId))

      logger.info("✅ WebRTCEngine: Answer created and local description set for \(userId)")
      return answer
    } catch {
      logger.error("❌ WebRTCEngine: Failed to handle remote offer for \(userId): \(error)")
      eventsContinuation.yield(.errorOccurred(error: .failedToSetDescription, userId: userId))
      throw error
    }
  }

  /// Set remote answer
  /// - Parameters:
  ///   - answer: The remote SDP answer
  ///   - userId: The user ID this answer is from
  public func setRemoteAnswer(_ answer: RTCSessionDescription, for userId: String) async throws {
    guard let peerConnection = peerConnections[userId] else {
      logger.error("❌ WebRTCEngine: No peer connection found for \(userId)")
      throw WebRTCError.peerConnectionNotFound
    }

    logger.info("📞 WebRTCEngine: Setting remote answer for \(userId)")

    do {
      try await peerConnection.setRemoteDescription(answer)
      logger.info("✅ WebRTCEngine: Remote answer set for \(userId)")
    } catch {
      logger.error("❌ WebRTCEngine: Failed to set remote answer for \(userId): \(error)")
      eventsContinuation.yield(.errorOccurred(error: .failedToSetDescription, userId: userId))
      throw error
    }
  }

  /// Add an ICE candidate
  /// - Parameters:
  ///   - candidate: The ICE candidate to add
  ///   - userId: The user ID this candidate is for
  public func addIceCandidate(_ candidate: RTCIceCandidate, for userId: String) async throws {
    guard let peerConnection = peerConnections[userId] else {
      logger.error("❌ WebRTCEngine: No peer connection found for \(userId)")
      throw WebRTCError.peerConnectionNotFound
    }

    logger.info("🧊 WebRTCEngine: Adding ICE candidate for \(userId)")

    do {
      try await peerConnection.add(candidate)
      logger.info("✅ WebRTCEngine: ICE candidate added for \(userId)")
    } catch {
      logger.error("❌ WebRTCEngine: Failed to add ICE candidate for \(userId): \(error)")
      eventsContinuation.yield(.errorOccurred(error: .failedToAddCandidate, userId: userId))
      throw error
    }
  }

  // MARK: - Internal Methods

  /// Handle events from AsyncStream internally
  private func handleWebRTCEvent(_ event: WebRTCEvent) {
    switch event {
    case .videoTrackAdded(let trackInfo):
      // Update internal state
      if !remoteVideoTracks.contains(where: { $0.userId == trackInfo.userId }) {
        remoteVideoTracks.append(trackInfo)
        logger.info("✅ WebRTCEngine: Added remote video track for \(trackInfo.userId)")
      }
    
    case .connectionStateChanged(let stateString, let userId):
      // Update connection states - we need to convert string back to RTCPeerConnectionState
      // This is a limitation of using string in events, but keeps events Sendable
      if let connection = peerConnections[userId] {
        let state = connection.connectionState
        if let index = connectionStates.firstIndex(where: { $0.userId == userId }) {
          connectionStates[index] = PeerConnectionInfo(userId: userId, connectionState: state)
        } else {
          connectionStates.append(PeerConnectionInfo(userId: userId, connectionState: state))
        }
        logger.info("🔗 WebRTCEngine: Connection state for \(userId): \(stateString)")
      }
    
    case .videoTrackRemoved(let userId):
      remoteVideoTracks.removeAll { $0.userId == userId }
      logger.info("📺 WebRTCEngine: Removed video track for \(userId)")
      
    default:
      // Other events are handled externally by signaling layer
      break
    }
  }
}