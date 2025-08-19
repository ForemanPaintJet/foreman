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
  /// All state changes (video tracks, connection states, etc.) are communicated through this stream
  public var events: @Sendable () -> AsyncStream<WebRTCEvent> = { AsyncStream.never }
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
        await engine.createPeerConnection(for: userId)
      },
      removePeerConnection: { userId in
        await engine.removePeerConnection(for: userId)
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

