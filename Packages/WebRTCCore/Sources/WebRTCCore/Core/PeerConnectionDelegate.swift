//
//  PeerConnectionDelegate.swift
//  WebRTCCore
//
//  Created by Claude on 2025/8/18.
//

import Foundation
import OSLog
import WebRTC

// MARK: - Peer Connection Delegate

/// Internal delegate for handling RTCPeerConnection events
/// This class bridges RTCPeerConnectionDelegate events to AsyncStream events
class PeerConnectionDelegate: NSObject, RTCPeerConnectionDelegate {

  // MARK: - Properties

  private let userId: String
  private let eventsContinuation: AsyncStream<WebRTCEvent>.Continuation
  private let logger = Logger(subsystem: "WebRTCCore", category: "PeerConnectionDelegate")

  // MARK: - Initialization

  init(userId: String, eventsContinuation: AsyncStream<WebRTCEvent>.Continuation) {
    self.userId = userId
    self.eventsContinuation = eventsContinuation
    super.init()
  }

  // MARK: - RTCPeerConnectionDelegate

  func peerConnection(
    _ peerConnection: RTCPeerConnection,
    didChange stateChanged: RTCSignalingState
  ) {
    logger.info("🔗 PeerConnection[\(self.userId)]: Signaling state changed to \(String(describing: stateChanged))")
  }

  func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
    logger.info(
      "📺 PeerConnection[\(self.userId)]: Legacy stream added with \(stream.audioTracks.count) audio tracks and \(stream.videoTracks.count) video tracks"
    )
    logger.info(
      "📺 PeerConnection[\(self.userId)]: Skipping legacy stream handling - using modern track-based approach"
    )
    // We use the modern didAdd receiver method instead
  }

  func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
    logger.info("📺 PeerConnection[\(self.userId)]: Stream removed")
    // Video track removal is handled in didRemove receiver method
  }

  // MARK: - Modern Track-based Delegate Methods

  func peerConnection(
    _ peerConnection: RTCPeerConnection,
    didAdd receiver: RTCRtpReceiver,
    streams: [RTCMediaStream]
  ) {
    logger.info("📺 PeerConnection[\(self.userId)]: Modern track added via receiver")
    logger.info("📺 PeerConnection[\(self.userId)]: Track kind: \(receiver.track?.kind ?? "unknown")")
    logger.info("📺 PeerConnection[\(self.userId)]: Track enabled: \(receiver.track?.isEnabled ?? false)")

    if let track = receiver.track, track.kind == "video",
      let videoTrack = track as? RTCVideoTrack
    {
      logger.info("📺 PeerConnection[\(self.userId)]: Video track received - sending event")
      let trackInfo = VideoTrackInfo(
        id: UUID().uuidString,
        userId: self.userId,
        track: videoTrack
      )
      eventsContinuation.yield(.videoTrackAdded(trackInfo: trackInfo))
    } else if let track = receiver.track, track.kind == "audio" {
      logger.info("🔊 PeerConnection[\(self.userId)]: Audio track received")
    }
  }

  func peerConnection(_ peerConnection: RTCPeerConnection, didRemove receiver: RTCRtpReceiver) {
    logger.info("📺 PeerConnection[\(self.userId)]: Modern track removed via receiver")

    if let track = receiver.track, track.kind == "video" {
      // Track removal is handled automatically when the peer connection is removed
      logger.info("📺 PeerConnection[\(self.userId)]: Video track removed")
    }
  }

  func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
    logger.info("🧊 PeerConnection[\(self.userId)]: ICE candidate generated")
    logger.info("🧊 PeerConnection[\(self.userId)]: Candidate SDP: \(candidate.sdp)")

    eventsContinuation.yield(.iceCandidateGenerated(
      candidate: candidate.sdp,
      sdpMLineIndex: Int(candidate.sdpMLineIndex),
      sdpMid: candidate.sdpMid,
      userId: self.userId
    ))
  }

  func peerConnection(
    _ peerConnection: RTCPeerConnection,
    didRemove candidates: [RTCIceCandidate]
  ) {
    logger.info("🧊 PeerConnection[\(self.userId)]: ICE candidates removed")
  }

  func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
    logger.info("📡 PeerConnection[\(self.userId)]: Data channel opened")
  }

  func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
    logger.info("🔄 PeerConnection[\(self.userId)]: Should negotiate")
  }

  func peerConnection(
    _ peerConnection: RTCPeerConnection,
    didChange newState: RTCIceConnectionState
  ) {
    logger.info("🧊 PeerConnection[\(self.userId)]: ICE connection state changed to \(String(describing: newState))")

    eventsContinuation.yield(.iceConnectionStateChanged(state: newState.description, userId: self.userId))
  }

  func peerConnection(
    _ peerConnection: RTCPeerConnection,
    didChange newState: RTCIceGatheringState
  ) {
    logger.info("🧊 PeerConnection[\(self.userId)]: ICE gathering state changed to \(String(describing: newState))")
  }

  func peerConnection(
    _ peerConnection: RTCPeerConnection,
    didChange newState: RTCPeerConnectionState
  ) {
    logger.info("🔗 PeerConnection[\(self.userId)]: Peer connection state changed to \(String(describing: newState))")

    eventsContinuation.yield(.connectionStateChanged(state: newState.description, userId: self.userId))
  }
}