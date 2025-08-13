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
        await store.send(.binding(\.mqttInfo.address), "192.168.1.100") {
            $0.mqttInfo.address = "192.168.1.100"
        }
        await store.send(.binding(\.mqttInfo.port), 1884) {
            $0.mqttInfo.port = 1884
        }
        await store.send(.binding(\.userId), "testUser") {
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
}
