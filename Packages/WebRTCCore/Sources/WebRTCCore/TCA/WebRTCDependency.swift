//
//  WebRTCDependency.swift
//  WebRTCCore
//
//  Created by Claude on 2025/8/18.
//

import ComposableArchitecture
import Foundation
import WebRTC

// MARK: - WebRTC Dependency

/// Modern TCA dependency for WebRTC functionality
/// Uses AsyncStream for event handling instead of delegate pattern
@DependencyClient
public struct WebRTCDependency {

  // MARK: - Core Operations

  /// Create a peer connection for a user
  public var createPeerConnection: @Sendable (String) async -> Bool = { _ in false }

  /// Remove a peer connection for a user
  public var removePeerConnection: @Sendable (String) async -> Void

  /// Create an offer for a user
  public var createOffer: @Sendable (String) async throws -> Void

  /// Set remote offer and return generated answer
  public var setRemoteOffer: @Sendable (RTCSessionDescription, String) async throws -> RTCSessionDescription

  /// Set remote answer
  public var setRemoteAnswer: @Sendable (RTCSessionDescription, String) async throws -> Void

  /// Add ICE candidate
  public var addIceCandidate: @Sendable (RTCIceCandidate, String) async throws -> Void

  // MARK: - Event Stream (replaces delegate pattern)

  /// Stream of WebRTC events for modern async handling
  public var events: @Sendable () -> AsyncStream<WebRTCEvent> = { AsyncStream.never }

  // MARK: - State Access

  /// Get current video tracks
  public var getVideoTracks: @Sendable () async -> [VideoTrackInfo] = { [] }

  /// Get current connection states
  public var getConnectionStates: @Sendable () async -> [PeerConnectionInfo] = { [] }

  /// Get connected peers
  public var getConnectedPeers: @Sendable () async -> [String] = { [] }

  // MARK: - Engine Access

  /// Get the WebRTC engine instance (for advanced usage)
  public var getEngine: @Sendable () async -> WebRTCEngine = { await MainActor.run { WebRTCEngine() } }
}

// MARK: - Dependency Keys

extension WebRTCDependency: TestDependencyKey {
  public static let testValue = Self()
}

extension WebRTCDependency: DependencyKey {
  public static let liveValue: Self = {
    let engine = WebRTCEngine()
    
    return WebRTCDependency(
      createPeerConnection: { userId in
        await MainActor.run {
          engine.createPeerConnection(for: userId)
        }
      },
      removePeerConnection: { userId in
        await MainActor.run {
          engine.removePeerConnection(for: userId)
        }
      },
      createOffer: { userId in
        try await engine.createOffer(for: userId)
      },
      setRemoteOffer: { offer, userId in
        try await engine.setRemoteOffer(offer, for: userId)
      },
      setRemoteAnswer: { answer, userId in
        try await engine.setRemoteAnswer(answer, for: userId)
      },
      addIceCandidate: { candidate, userId in
        try await engine.addIceCandidate(candidate, for: userId)
      },
      events: {
        engine.events
      },
      getVideoTracks: {
        await MainActor.run {
          engine.videoTracks
        }
      },
      getConnectionStates: {
        await MainActor.run {
          engine.connectionStates
        }
      },
      getConnectedPeers: {
        await MainActor.run {
          engine.connectedPeers
        }
      },
      getEngine: {
        await MainActor.run {
          engine
        }
      }
    )
  }()
}

// MARK: - Dependency Values Extension

public extension DependencyValues {
  var webRTCEngine: WebRTCDependency {
    get { self[WebRTCDependency.self] }
    set { self[WebRTCDependency.self] = newValue }
  }
}

