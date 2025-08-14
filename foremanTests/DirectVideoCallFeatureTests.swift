//
//  DirectVideoCallFeatureTests.swift
//  foremanTests
//
//  Created by Claude on 2025/8/13.
//

import ComposableArchitecture
import Testing

@testable import foreman

@Suite("DirectVideoCallFeature")
@MainActor
struct DirectVideoCallFeatureTests {
    @Test("initial state values")
    func testInitialState() async throws {
        let state = DirectVideoCallFeature.State()
        #expect(state.batteryLevel == 100)
        #expect(state.showConfig == false)
        #expect(state.showHumanPose == false)
        #expect(state.showWifiDetails == false)
        #expect(state.currentAlert == .none)
        #expect(state.distanceFt > 0) // Should have a default random value
    }

    @Test("binding updates work correctly")
    func bindingUpdates() async throws {
        let store = TestStore(
            initialState: DirectVideoCallFeature.State(), reducer: { DirectVideoCallFeature() }
        )

        await store.send(.binding(.set(\.batteryLevel, 80))) {
            $0.batteryLevel = 80
        }

        await store.send(.binding(.set(\.showConfig, true))) {
            $0.showConfig = true
        }

        await store.send(.binding(.set(\.showWifiDetails, true))) {
            $0.showWifiDetails = true
        }
    }

    @Test("show config toggle")
    func testShowConfig() async throws {
        let store = TestStore(
            initialState: DirectVideoCallFeature.State(), reducer: { DirectVideoCallFeature() }
        )

        await store.send(.view(.showConfig(true))) {
            $0.showConfig = true
        }

        await store.send(.view(.showConfig(false))) {
            $0.showConfig = false
        }
    }

    @Test("show human pose toggle")
    func testShowHumanPose() async throws {
        let store = TestStore(
            initialState: DirectVideoCallFeature.State(), reducer: { DirectVideoCallFeature() }
        )

        await store.send(.view(.showHumanPose(true))) {
            $0.showHumanPose = true
        }

        await store.send(.view(.showHumanPose(false))) {
            $0.showHumanPose = false
        }
    }

    @Test("toggle wifi details")
    func testToggleWifiDetails() async throws {
        let store = TestStore(
            initialState: DirectVideoCallFeature.State(showWifiDetails: false),
            reducer: { DirectVideoCallFeature() }
        )

        await store.send(.view(.toggleWifiDetails)) {
            $0.showWifiDetails = true
        }

        await store.send(.view(.toggleWifiDetails)) {
            $0.showWifiDetails = false
        }
    }

    @Test("close config")
    func testCloseConfig() async throws {
        let store = TestStore(
            initialState: DirectVideoCallFeature.State(showConfig: true),
            reducer: { DirectVideoCallFeature() }
        )

        await store.send(.view(.closeConfig)) {
            $0.showConfig = false
        }
    }

    @Test("close human pose")
    func testCloseHumanPose() async throws {
        let store = TestStore(
            initialState: DirectVideoCallFeature.State(showHumanPose: true),
            reducer: { DirectVideoCallFeature() }
        )

        await store.send(.view(.closeHumanPose)) {
            $0.showHumanPose = false
        }
    }

    @Test("simulate alert")
    func testSimulateAlert() async throws {
        let store = TestStore(
            initialState: DirectVideoCallFeature.State(), reducer: { DirectVideoCallFeature() }
        )

        await store.send(.view(.simulateAlert(.green))) {
            $0.currentAlert = .green
        }

        await store.send(.view(.simulateAlert(.red))) {
            $0.currentAlert = .red
        }

        await store.send(.view(.simulateAlert(.yellow))) {
            $0.currentAlert = .yellow
        }
    }

    @Test("battery level changed")
    func testBatteryLevelChanged() async throws {
        let store = TestStore(
            initialState: DirectVideoCallFeature.State(), reducer: { DirectVideoCallFeature() }
        )

        await store.send(._internal(.batteryLevelChanged(75))) {
            $0.batteryLevel = 75
        }

        await store.send(._internal(.batteryLevelChanged(25))) {
            $0.batteryLevel = 25
        }

        await store.send(._internal(.batteryLevelChanged(1))) {
            $0.batteryLevel = 1
        }
    }

//    @Test("delegate actions do not change state")
//    func delegateActions() async throws {
//        let store = TestStore(
//            initialState: DirectVideoCallFeature.State(), reducer: { DirectVideoCallFeature() }
//        )
//
//        // Delegate actions should not modify state
//        await store.send(.delegate(.configClosed))
//        await store.send(.delegate(.humanPoseClosed))
//        await store.send(.delegate(.alertSimulated(.intruder)))
//    }

    @Test("multiple state changes")
    func multipleStateChanges() async throws {
        let store = TestStore(
            initialState: DirectVideoCallFeature.State(), reducer: { DirectVideoCallFeature() }
        )

        // Test multiple state changes in sequence
        await store.send(.view(.showConfig(true))) {
            $0.showConfig = true
        }

        await store.send(.view(.showHumanPose(true))) {
            $0.showHumanPose = true
        }

        await store.send(.view(.toggleWifiDetails)) {
            $0.showWifiDetails = true
        }

        await store.send(._internal(.batteryLevelChanged(6))) {
            $0.batteryLevel = 6
        }

        await store.send(.view(.simulateAlert(.red))) {
            $0.currentAlert = .red
        }

        // Verify final state
        #expect(store.state.showConfig == true)
        #expect(store.state.showHumanPose == true)
        #expect(store.state.showWifiDetails == true)
        #expect(store.state.batteryLevel == 6)
        #expect(store.state.currentAlert == .red)
    }

    @Test("reset operations")
    func resetOperations() async throws {
        // Start with a state that has various values set
        let initialState = DirectVideoCallFeature.State(
            showConfig: true,
            showHumanPose: true,
            showWifiDetails: true,
            distanceFt: 75.0,
            batteryLevel: 8,
            currentAlert: .red
        )

        let store = TestStore(
            initialState: initialState, reducer: { DirectVideoCallFeature() }
        )

        // Close various UI elements
        await store.send(.view(.closeConfig)) {
            $0.showConfig = false
        }

        await store.send(.view(.closeHumanPose)) {
            $0.showHumanPose = false
        }

        await store.send(.view(.toggleWifiDetails)) {
            $0.showWifiDetails = false
        }

        // Clear alert by setting to nil
        await store.send(.view(.simulateAlert(.none))) {
            $0.currentAlert = .none
        }
    }
}
