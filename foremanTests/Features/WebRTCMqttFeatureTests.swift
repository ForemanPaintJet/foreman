//
//  WebRTCMqttFeatureTests.swift
//  foremanTests
//
//  Created by Jed Lu on 2025/7/18.
//

import ComposableArchitecture
import MQTTNIO
import NIOCore
import Testing
import WebRTC
import WebRTCCore

@testable import foreman

@Suite("WebRTCMqttFeature")
@MainActor
struct WebRTCMqttFeatureTests {
    @Test("generateDefaultUserId sets userId and clientID")
    func testGenerateDefaultUserId() async throws {
        var state = WebRTCMqttFeature.State()
        state.generateDefaultUserId()
        #expect(state.userId.hasPrefix("user_"))
        #expect(state.mqttFeature.connectionInfo.clientID == state.userId)
    }

    @Test("binding updates MQTT info and userId")
    func testBindingUpdates() async throws {
        let store = TestStore(
            initialState: WebRTCMqttFeature.State(), reducer: { WebRTCMqttFeature() })
        
        await store.send(.binding(.set(\.userId, "testUser"))) {
            $0.userId = "testUser"
            $0.mqttFeature.connectionInfo.clientID = "testUser"
        }
    }

    @Test("clear error")
    func testClearError() async throws {
        let store = TestStore(
            initialState: WebRTCMqttFeature.State(lastError: "Some error"),
            reducer: { WebRTCMqttFeature() })
        await store.send(.view(.clearError)) {
            $0.lastError = nil
        }
    }

    // Connection status is now managed by MqttFeature

    @Test("set loading state")
    func testSetLoading() async throws {
        let store = TestStore(
            initialState: WebRTCMqttFeature.State(), reducer: { WebRTCMqttFeature() })
        await store.send(._internal(.setLoading(.connecting, true))) {
            $0.loadingItems.insert(.connecting)
        }
        await store.send(._internal(.setLoading(.connecting, false))) {
            $0.loadingItems.remove(.connecting)
        }
    }

    @Test("error occurred updates lastError")
    func testErrorOccurred() async throws {
        let store = TestStore(
            initialState: WebRTCMqttFeature.State(), reducer: { WebRTCMqttFeature() })
        
        await store.send(._internal(.errorOccurred("Connection failed"))) {
            $0.lastError = "Connection failed"
        }
        
        await store.receive(.delegate(.connectionError("Connection failed")))
    }

    // Message handling is now managed by MqttFeature

    @Test("offer received updates pendingOffers and sends to WebRTCFeature")
    func testOfferReceived() async throws {
        let store = TestStore(initialState: WebRTCMqttFeature.State(userId: "user123")) {
            WebRTCMqttFeature()
        } withDependencies: {
            $0.webRTCEngine.setRemoteOffer = { _ in throw WebRTCError.failedToSetDescription }
        }
        
        store.exhaustivity = .off(showSkippedAssertions: true)
        
        let offer = WebRTCOffer(sdp: "test-sdp", type: "offer", from: "client1", to: "user123", videoSource: "")
        
        await store.send(._internal(.offerReceived(offer))) {
            $0.pendingOffers = [offer]
        }
        
        // Expect the WebRTCFeature to receive the properly formatted offer
        await store.receive(.webRTCFeature(.view(.handleRemoteOffer(offer))))
    }

    @Test("ice candidate received updates pendingIceCandidates and sends to WebRTCFeature")
    func testIceCandidateReceived() async throws {
        let store = TestStore(initialState: WebRTCMqttFeature.State(userId: "user123")) {
            WebRTCMqttFeature()
        } withDependencies: {
            $0.webRTCEngine.addIceCandidate = { _ in throw WebRTCError.failedToAddCandidate }
        }
        
        let iceCandidate = ICECandidate(
            type: "ice", from: "client1", to: "user123",
            candidate: .init(candidate: "test-candidate", sdpMLineIndex: 0, sdpMid: "0"))
        
        store.exhaustivity = .off(showSkippedAssertions: true)
        
        await store.send(._internal(.iceCandidateReceived(iceCandidate))) {
            $0.pendingIceCandidates = [iceCandidate]
        }
        
        // Expect the WebRTCFeature to receive the properly formatted ICE candidate
        await store.receive(.webRTCFeature(.view(.handleICECandidate(iceCandidate))))
    }

    @Test("delegate actions do not change state")
    func testDelegateActions() async throws {
        let store = TestStore(
            initialState: WebRTCMqttFeature.State(), reducer: { WebRTCMqttFeature() })
        
        await store.send(.delegate(.didConnect))
        await store.send(.delegate(.didDisconnect))
        await store.send(.delegate(.connectionError("test")))
    }
    
    // MARK: - WebRTCFeature Delegate Tests
    
    @Test("WebRTCFeature delegate offerGenerated creates and publishes MQTT offer")
    func testWebRTCDelegateOfferGenerated() async throws {
        let store = TestStore(
            initialState: WebRTCMqttFeature.State(userId: "user123"),
            reducer: { WebRTCMqttFeature() }
        )
        
        store.exhaustivity = .off(showSkippedAssertions: true)
        await store.send(.webRTCFeature(.delegate(.offerGenerated(sdp: "test-offer-sdp", userId: "client1"))))
        
        await store.receive(._internal(.webRTCOfferGenerated(WebRTCOffer(
            sdp: "test-offer-sdp", 
            type: "offer", 
            from: "user123", 
            to: "client1", 
            videoSource: ""
        ))))
    }
    
    @Test("WebRTCFeature delegate answerGenerated creates and publishes MQTT answer")
    func testWebRTCDelegateAnswerGenerated() async throws {
        let store = TestStore(
            initialState: WebRTCMqttFeature.State(userId: "user123"),
            reducer: { WebRTCMqttFeature() }
        )
        
        store.exhaustivity = .off(showSkippedAssertions: true)
        await store.send(.webRTCFeature(.delegate(.answerGenerated(sdp: "test-answer-sdp", userId: "client1"))))
        
        await store.receive(._internal(.webRTCAnswerGenerated(WebRTCAnswer(
            sdp: "test-answer-sdp", 
            type: "answer", 
            from: "user123", 
            to: "client1", 
            videoSource: ""
        ))))
    }
    
    @Test("WebRTCFeature delegate iceCandidateGenerated creates and publishes MQTT ICE candidate")
    func testWebRTCDelegateIceCandidateGenerated() async throws {
        let store = TestStore(
            initialState: WebRTCMqttFeature.State(userId: "user123"),
            reducer: { WebRTCMqttFeature() }
        )
        
        store.exhaustivity = .off(showSkippedAssertions: true)
        await store.send(.webRTCFeature(.delegate(.iceCandidateGenerated(
            candidate: "test-candidate", 
            sdpMLineIndex: 0, 
            sdpMid: "0", 
            userId: "client1"
        ))))
        
        await store.receive(._internal(.webRTCIceCandidateGenerated(ICECandidate(
            type: "ice",
            from: "user123",
            to: "client1",
            candidate: .init(
                candidate: "test-candidate",
                sdpMLineIndex: 0,
                sdpMid: "0"
            )
        ))))
    }
    
    @Test("WebRTCFeature delegate videoTrackAdded updates DirectVideoCall feature")
    func testWebRTCDelegateVideoTrackAdded() async throws {
        let store = TestStore(
            initialState: WebRTCMqttFeature.State(),
            reducer: { WebRTCMqttFeature() }
        )
        
        let videoTrackInfo = VideoTrackInfo(id: "track1", userId: "client1", track: nil)
        
        await store.send(.webRTCFeature(.delegate(.videoTrackAdded(videoTrackInfo)))) {
            // Should update DirectVideoCall feature with new video track
            $0.directVideoCall.remoteVideoTracks.append(videoTrackInfo)
        }
    }
    
    @Test("WebRTCFeature delegate videoTrackRemoved updates DirectVideoCall feature")
    func testWebRTCDelegateVideoTrackRemoved() async throws {
        // Setup initial state with some video tracks
        var initialState = WebRTCMqttFeature.State()
        let existingTrack = VideoTrackInfo(id: "track1", userId: "client1", track: nil)
        initialState.directVideoCall.remoteVideoTracks = [existingTrack]
        
        let store = TestStore(
            initialState: initialState,
            reducer: { WebRTCMqttFeature() }
        )
        
        await store.send(.webRTCFeature(.delegate(.videoTrackRemoved(userId: "client1")))) {
            // Should update DirectVideoCall feature by removing video tracks
            $0.directVideoCall.remoteVideoTracks = $0.webRTCFeature.connectedPeers.compactMap { $0.videoTrack }
        }
    }
    
    @Test("WebRTCFeature delegate errorOccurred propagates error")
    func testWebRTCDelegateErrorOccurred() async throws {
        let store = TestStore(
            initialState: WebRTCMqttFeature.State(),
            reducer: { WebRTCMqttFeature() }
        )
        
        await store.send(.webRTCFeature(.delegate(.errorOccurred(.failedToSetDescription, userId: "client1"))))
        
        await store.receive(._internal(.errorOccurred("WebRTC Error: Failed to set session description"))) {
            $0.lastError = "WebRTC Error: Failed to set session description"
        }
        
        await store.receive(.delegate(.connectionError("WebRTC Error: Failed to set session description")))
    }
    
    // MARK: - MQTT Message Parsing Tests
    // Note: Message parsing is now handled by MqttFeature delegate
    
    
    
    
    @Test("room operations update state correctly")
    func testRoomOperations() async throws {
        let store = TestStore(
            initialState: WebRTCMqttFeature.State(),
            reducer: { WebRTCMqttFeature() }
        )
        
        // Test room joined
        await store.send(._internal(.roomJoined)) {
            $0.isJoinedToRoom = true
        }
        
        // Test room left
        await store.send(._internal(.roomLeft)) {
            $0.isJoinedToRoom = false
            $0.connectedUsers = []
        }
    }
}
