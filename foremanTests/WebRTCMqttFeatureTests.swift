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

    @Test("offer received updates pendingOffers")
    func testOfferReceived() async throws {
        let store = TestStore(
            initialState: WebRTCMqttFeature.State(), reducer: { WebRTCMqttFeature() }){
                $0.webRTCClient.handleRemoteOffer = { _ in
                    throw Unimplemented("")
                }
            }
        
        let offer = WebRTCOffer(sdp: "test-sdp", type: "offer", clientId: "client1", videoSource: "")
        
        await store.send(._internal(.offerReceived(offer))) {
            $0.pendingOffers.append(offer)
        }
        
        let errorString = "Failed to handle remote offer: The operation couldn’t be completed. (DependenciesMacros.Unimplemented error 1.)"
        
        await store.receive(._internal(.errorOccurred(errorString))) {
            $0.lastError = errorString
        }
        
        await store.receive(.delegate(.connectionError(errorString)))
    }

    @Test("answer received updates pendingAnswers")
    func testAnswerReceived() async throws {
        let store = TestStore(
            initialState: WebRTCMqttFeature.State(), reducer: { WebRTCMqttFeature() }) {
                $0.webRTCClient.handleRemoteAnswer = { _ in
                    throw Unimplemented("")
                }
            }
        
        let answer = WebRTCAnswer(sdp: "test-sdp", type: "answer", clientId: "client1", videoSource: "")
        
        await store.send(._internal(.answerReceived(answer))) {
            $0.pendingAnswers.append(answer)
        }
        
        let errorString = "Failed to handle remote answer: The operation couldn’t be completed. (DependenciesMacros.Unimplemented error 1.)"
        
        await store.receive(._internal(.errorOccurred(errorString))) {
            $0.lastError = errorString
        }
        
        await store.receive(.delegate(.connectionError(errorString)))
    }

    @Test("ice candidate received updates pendingIceCandidates")
    func testIceCandidateReceived() async throws {
        let store = TestStore(
            initialState: WebRTCMqttFeature.State(), reducer: { WebRTCMqttFeature() }) {
                $0.webRTCClient.handleRemoteIceCandidate = { _ in
                    throw Unimplemented("")
                }
            }
        let iceCandidate = ICECandidate(
            type: "ice", clientId: "client1",
            candidate: .init(candidate: "test-candidate", sdpMLineIndex: 0, sdpMid: "0"))
        
        await store.send(._internal(.iceCandidateReceived(iceCandidate))) {
            $0.pendingIceCandidates.append(iceCandidate)
        }
        
        let errorString = "Failed to handle remote ICE candidate: The operation couldn’t be completed. (DependenciesMacros.Unimplemented error 1.)"
        
        await store.receive(._internal(.errorOccurred(errorString))) {
            $0.lastError = errorString
        }
        
        await store.receive(.delegate(.connectionError(errorString)))
    }

    @Test("delegate actions do not change state")
    func testDelegateActions() async throws {
        let store = TestStore(
            initialState: WebRTCMqttFeature.State(), reducer: { WebRTCMqttFeature() })
        
        await store.send(.delegate(.didConnect))
        await store.send(.delegate(.didDisconnect))
        await store.send(.delegate(.connectionError("test")))
    }
}
