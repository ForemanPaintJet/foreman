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
        #expect(state.mqttInfo.clientID == state.userId)
    }

    @Test("binding updates MQTT info and userId")
    func testBindingUpdates() async throws {
        let store = TestStore(
            initialState: WebRTCMqttFeature.State(), reducer: { WebRTCMqttFeature() })
        await store.send(.binding(.set(\.mqttInfo.address, "192.168.1.100"))) {
            $0.mqttInfo.address = "192.168.1.100"
        }
        
        await store.send(.binding(.set(\.mqttInfo.port, 1884))) {
            $0.mqttInfo.port = 1884
        }
        
        await store.send(.binding(.set(\.userId, "testUser"))) {
            $0.userId = "testUser"
            $0.mqttInfo.clientID = "testUser"
        }
    }

    @Test("clear messages and error")
    func testClearMessagesAndError() async throws {
        let store = TestStore(
            initialState: WebRTCMqttFeature.State(
                lastError: "Some error",
                messages: [
                    MQTTPublishInfo(
                        qos: .atLeastOnce, retain: false, topicName: "test", payload: ByteBuffer(),
                        properties: .init([]))
                ]), reducer: { WebRTCMqttFeature() })
        await store.send(.view(.clearMessages)) {
            $0.messages = []
        }
        await store.send(.view(.clearError)) {
            $0.lastError = nil
        }
    }

    @Test("connection status changed")
    func testConnectionStatusChanged() async throws {
        let store = TestStore(
            initialState: WebRTCMqttFeature.State(connectionStatus: .idle),
            reducer: { WebRTCMqttFeature() })
        await store.send(._internal(.connectionStatusChanged(.connected))) {
            $0.connectionStatus = .connected
        }
    }

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

    @Test("message received appends to messages and limits to 50")
    func testMessageReceived() async throws {
        // Create 50 existing messages
        let existingMessages = (0..<50).map { i in
            MQTTPublishInfo(
                qos: .atLeastOnce, retain: false, topicName: "test\(i)", payload: ByteBuffer(),
                properties: .init([]))
        }
        
        let store = TestStore(
            initialState: WebRTCMqttFeature.State(messages: existingMessages),
            reducer: { WebRTCMqttFeature() })
        
        let newMessage = MQTTPublishInfo(
            qos: .atLeastOnce, retain: false, topicName: "newTest", payload: ByteBuffer(),
            properties: .init([]))
        
        await store.send(._internal(.mqttMessageReceived(newMessage))) {
            // Should remove first message and append new one
            $0.messages.removeFirst()
            $0.messages.append(newMessage)
            #expect($0.messages.count == 50)
        }
    }

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
    
    @Test("MQTT offer message parsing and filtering")
    func testMQTTOfferMessageParsing() async throws {
        let store = TestStore(initialState: WebRTCMqttFeature.State(userId: "user123")) {
            WebRTCMqttFeature()
        } withDependencies: {
            $0.webRTCEngine.setRemoteOffer = { _ in throw WebRTCError.failedToSetDescription }
        }
        
        // Create MQTT message with offer
        let offerJSON = """
        {
            "type": "offer",
            "clientId": "client1",
            "sdp": "test-offer-sdp",
            "videoSource": ""
        }
        """
        let payload = ByteBuffer(data: Data(offerJSON.utf8))
        let mqttMessage = MQTTPublishInfo(
            qos: .atLeastOnce,
            retain: false,
            topicName: "camera_system/streaming/out",
            payload: payload,
            properties: .init([])
        )
        
        store.exhaustivity = .off(showSkippedAssertions: true)
        
        await store.send(._internal(.mqttMessageReceived(mqttMessage))) {
            $0.messages = [mqttMessage]
        }
        
        // Should parse and forward to WebRTCFeature
        await store.receive(._internal(.offerReceived(WebRTCOffer(
            sdp: "test-offer-sdp",
            type: "offer",
            from: "client1",
            to: "user123",
            videoSource: ""
        )))) {
            $0.pendingOffers = [WebRTCOffer(
                sdp: "test-offer-sdp",
                type: "offer",
                from: "client1",
                to: "user123",
                videoSource: ""
            )]
        }
        
        await store.receive(.webRTCFeature(.view(.handleRemoteOffer(WebRTCOffer(
            sdp: "test-offer-sdp",
            type: "offer",
            from: "client1",
            to: "user123",
            videoSource: ""
        )))))
    }
    
    @Test("MQTT offer message from self is ignored")
    func testMQTTOfferMessageSelfFiltering() async throws {
        let store = TestStore(
            initialState: WebRTCMqttFeature.State(userId: "user123"),
            reducer: { WebRTCMqttFeature() }
        )
        
        // Create MQTT message with offer from self
        let offerJSON = """
        {
            "type": "offer",
            "clientId": "user123",
            "sdp": "test-offer-sdp",
            "videoSource": ""
        }
        """
        let payload = ByteBuffer(data: Data(offerJSON.utf8))
        let mqttMessage = MQTTPublishInfo(
            qos: .atLeastOnce,
            retain: false,
            topicName: "camera_system/streaming/out",
            payload: payload,
            properties: .init([])
        )
        
        await store.send(._internal(.mqttMessageReceived(mqttMessage))) {
            $0.messages.append(mqttMessage)
            // Should not add to pending offers since it's from self
        }
        
        // Should not receive any further actions since message is ignored
    }
    
    @Test("MQTT ICE candidate message parsing")
    func testMQTTIceCandidateMessageParsing() async throws {
        let store = TestStore(initialState: WebRTCMqttFeature.State(userId: "user123")) {
            WebRTCMqttFeature()
        } withDependencies: {
            $0.webRTCEngine.addIceCandidate = { _ in throw WebRTCError.failedToAddCandidate }
        }
        
        // Create MQTT message with ICE candidate
        let iceJSON = """
        {
            "type": "ice",
            "clientId": "client1",
            "candidate": {
                "candidate": "test-ice-candidate",
                "sdpMLineIndex": 0,
                "sdpMid": "0"
            }
        }
        """
        let payload = ByteBuffer(data: Data(iceJSON.utf8))
        let mqttMessage = MQTTPublishInfo(
            qos: .atLeastOnce,
            retain: false,
            topicName: "camera_system/streaming/out",
            payload: payload,
            properties: .init([])
        )
        
        store.exhaustivity = .off(showSkippedAssertions: true)
        
        await store.send(._internal(.mqttMessageReceived(mqttMessage))) {
            $0.messages = [mqttMessage]
        }
        
        // Should parse and forward to WebRTCFeature
        let expectedIceCandidate = ICECandidate(
            type: "ice",
            from: "client1",
            to: "user123",
            candidate: .init(
                candidate: "test-ice-candidate",
                sdpMLineIndex: 0,
                sdpMid: "0"
            )
        )
        
        await store.receive(._internal(.iceCandidateReceived(expectedIceCandidate))) {
            $0.pendingIceCandidates = [expectedIceCandidate]
        }
        
        await store.receive(.webRTCFeature(.view(.handleICECandidate(expectedIceCandidate))))
    }
    
    @Test("invalid MQTT message parsing handles gracefully")
    func testInvalidMQTTMessageParsing() async throws {
        let store = TestStore(
            initialState: WebRTCMqttFeature.State(),
            reducer: { WebRTCMqttFeature() }
        )
        
        // Create MQTT message with invalid JSON
        let invalidJSON = "{ invalid json content"
        let payload = ByteBuffer(data: Data(invalidJSON.utf8))
        let mqttMessage = MQTTPublishInfo(
            qos: .atLeastOnce,
            retain: false,
            topicName: "camera_system/streaming/out",
            payload: payload,
            properties: .init([])
        )
        
        await store.send(._internal(.mqttMessageReceived(mqttMessage))) {
            $0.messages.append(mqttMessage)
            // Should handle gracefully without crashing
        }
        
        // Should not receive any further actions since parsing failed
    }
    
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
