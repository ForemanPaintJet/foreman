//
//  WebRTCModels.swift
//  WebRTCCore
//
//  Created by Claude on 2025/8/18.
//

import Foundation
import WebRTC

// MARK: - Core WebRTC Models

/// Information about a video track from a peer
public struct VideoTrackInfo: Equatable, Identifiable {
  public let id: String
  public let userId: String
  public let track: RTCVideoTrack?

  public init(id: String, userId: String, track: RTCVideoTrack?) {
    self.id = id
    self.userId = userId
    self.track = track
  }

  public static func == (lhs: VideoTrackInfo, rhs: VideoTrackInfo) -> Bool {
    lhs.id == rhs.id && lhs.userId == rhs.userId
  }
}

/// Information about a peer connection state
public struct PeerConnectionInfo: Equatable {
  public let userId: String
  public let connectionState: RTCPeerConnectionState

  public init(userId: String, connectionState: RTCPeerConnectionState) {
    self.userId = userId
    self.connectionState = connectionState
  }
}

// MARK: - Signaling Models

/// WebRTC Offer message for signaling
public struct WebRTCOffer: Codable, Equatable {
  public let sdp: String
  public let type: String
  public let clientId: String
  public let videoSource: String

  public init(sdp: String, type: String, clientId: String, videoSource: String) {
    self.sdp = sdp
    self.type = type
    self.clientId = clientId
    self.videoSource = videoSource
  }
}

/// WebRTC Answer message for signaling
public struct WebRTCAnswer: Codable, Equatable {
  public let sdp: String
  public let type: String
  public let clientId: String
  public let videoSource: String

  public init(sdp: String, type: String, clientId: String, videoSource: String) {
    self.sdp = sdp
    self.type = type
    self.clientId = clientId
    self.videoSource = videoSource
  }
}

/// ICE Candidate for signaling
public struct ICECandidate: Codable, Equatable {
  public struct Candidate: Codable, Equatable {
    public let candidate: String
    public let sdpMLineIndex: Int
    public let sdpMid: String?

    public init(candidate: String, sdpMLineIndex: Int, sdpMid: String?) {
      self.candidate = candidate
      self.sdpMLineIndex = sdpMLineIndex
      self.sdpMid = sdpMid
    }
  }

  public let type: String
  public let clientId: String
  public let candidate: Candidate

  public init(type: String, clientId: String, candidate: Candidate) {
    self.type = type
    self.clientId = clientId
    self.candidate = candidate
  }
}

// MARK: - Event Types

/// Unified event system for WebRTC engine
/// Replaces delegate pattern with modern AsyncStream approach
public enum WebRTCEvent: Equatable, Sendable {
  // MARK: - SDP Events
  
  /// Offer was generated for a peer
  case offerGenerated(sdp: String, userId: String)
  
  /// Answer was generated for a peer
  case answerGenerated(sdp: String, userId: String)
  
  // MARK: - ICE Events
  
  /// ICE candidate was generated for a peer
  case iceCandidateGenerated(candidate: String, sdpMLineIndex: Int, sdpMid: String?, userId: String)
  
  // MARK: - Connection Events
  
  /// Peer connection state changed
  case connectionStateChanged(state: String, userId: String)
  
  /// ICE connection state changed
  case iceConnectionStateChanged(state: String, userId: String)
  
  // MARK: - Media Events
  
  /// Remote video track was added
  case videoTrackAdded(trackInfo: VideoTrackInfo)
  
  /// Remote video track was removed
  case videoTrackRemoved(userId: String)
  
  // MARK: - Error Events
  
  /// Error occurred in WebRTC engine
  case errorOccurred(error: WebRTCError, userId: String?)
}

// MARK: - Error Types

/// WebRTC specific errors
public enum WebRTCError: Error, LocalizedError, Equatable, Sendable {
  case peerConnectionNotFound
  case failedToCreateOffer
  case failedToCreateAnswer
  case failedToSetDescription
  case failedToAddCandidate
  case factoryInitializationFailed

  public var errorDescription: String? {
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
    case .factoryInitializationFailed:
      return "Failed to initialize peer connection factory"
    }
  }
}