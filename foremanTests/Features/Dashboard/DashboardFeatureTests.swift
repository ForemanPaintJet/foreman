//
//  DashboardFeatureTests.swift
//  foremanTests
//
//  Created by Claude on 2025/9/8.
//

import ComposableArchitecture
import MqttClientKit
import XCTest
import Dependencies

@testable import foreman

@MainActor
final class DashboardFeatureTests: XCTestCase {
  func testInitialState() async {
    let store = TestStore(
      initialState: DashboardFeature.State(),
      reducer: { DashboardFeature() }
    )
    
    // Test initial monitoring items
    expectNoDifference(store.state.monitoringItems.count, 5)
    expectNoDifference(store.state.monitoringItems.ids.first, ifstatOutputTopic)
    expectNoDifference(store.state.monitoringItems[id: ifstatOutputTopic]?.isMiniMode, true)
    
    // Test initial drawer state
    expectNoDifference(store.state.isDrawerOpen, false)
    expectNoDifference(store.state.drawerWidth, 350)
    expectNoDifference(store.state.isCompactLayout, false)
    expectNoDifference(store.state.isMiniMode, true)
    
    // Test initial sensor state
    expectNoDifference(store.state.sensorNodeStatus.isMiniMode, true)
  }
  
  func testTaskActionInitializesAllFeatures() async {
    let store = TestStore(
      initialState: DashboardFeature.State(),
      reducer: { DashboardFeature() }
    )
    
    store.exhaustivity = .off(showSkippedAssertions: true)
    
    await store.send(.view(.task))
    
    // Should receive task actions for DirectVideoCall and SensorNodeStatus
    await store.receive(\.directVideoCall.view.task)
    await store.receive(\.sensorNodeStatus.view.task)
    await store.receive(\.sensorNodeStatus.view.setMiniMode)
    
    await store.receive(.monitoringItems(.element(id: "network/ifstat/data", action: .view(.task))))
//    await store.receive(.monitoringItems(.element(id: "monitoring/cpu", action: .view(.task))))
    
//    // Should receive task actions for all monitoring items
//    for id in store.state.monitoringItems.ids {
//      print("Item id: \(id)")
//      await store.receive(.monitoringItems(.element(id: id, action: .view(.task))))
//      await store.receive(.monitoringItems(.element(id: id, action: .view(.setMiniMode(true)))))
//    }
  }
  
  func testToggleDrawer() async {
    let store = TestStore(
      initialState: DashboardFeature.State(isDrawerOpen: false),
      reducer: { DashboardFeature() }
    )
    
    await store.send(.view(.toggleDrawer)) {
      $0.isDrawerOpen = true
    }
    
    await store.send(.view(.toggleDrawer)) {
      $0.isDrawerOpen = false
    }
  }
  
  func testSetDrawerOpen() async {
    let store = TestStore(
      initialState: DashboardFeature.State(),
      reducer: { DashboardFeature() }
    )
    
    await store.send(.view(.setDrawerOpen(true))) {
      $0.isDrawerOpen = true
    }
    
    await store.send(.view(.setDrawerOpen(false))) {
      $0.isDrawerOpen = false
    }
  }
  
  func testSetDrawerWidth() async {
    let store = TestStore(
      initialState: DashboardFeature.State(),
      reducer: { DashboardFeature() }
    )
    
    await store.send(.view(.setDrawerWidth(400))) {
      $0.drawerWidth = 400
    }
    
    // Test clamping to minimum
    await store.send(.view(.setDrawerWidth(100))) {
      $0.drawerWidth = 250
    }
    
    // Test clamping to maximum
    await store.send(.view(.setDrawerWidth(600))) {
      $0.drawerWidth = 500
    }
  }
  
  func testSetCompactLayout() async {
    let store = TestStore(
      initialState: DashboardFeature.State(isDrawerOpen: true),
      reducer: { DashboardFeature() }
    )
    
    await store.send(.view(.setCompactLayout(true))) {
      $0.isCompactLayout = true
      $0.isDrawerOpen = false // Should auto-close drawer
    }
    
    await store.send(.view(.setCompactLayout(false))) {
      $0.isCompactLayout = false
    }
  }
  
  func testToggleMiniMode() async {
    let store = TestStore(
      initialState: DashboardFeature.State(isMiniMode: true),
      reducer: { DashboardFeature() }
    )
    
    store.exhaustivity = .off(showSkippedAssertions: true)
    
    await store.send(.view(.toggleMiniMode)) {
      $0.isMiniMode = false
    }
    
    // Should sync mini mode to all monitoring items
    for id in store.state.monitoringItems.ids {
      await store.receive(.monitoringItems(.element(id: id, action: .view(.setMiniMode(false)))))
    }
    
    // Should sync to sensor node status
    await store.receive(\.sensorNodeStatus.view.setMiniMode)
  }
  
  func testSetMiniMode() async {
    let store = TestStore(
      initialState: DashboardFeature.State(isMiniMode: true),
      reducer: { DashboardFeature() }
    )
    
    store.exhaustivity = .off(showSkippedAssertions: true)
    
    await store.send(.view(.setMiniMode(false))) {
      $0.isMiniMode = false
    }
    
    // Should sync mini mode to all monitoring items
    for id in store.state.monitoringItems.ids {
      await store.receive(.monitoringItems(.element(id: id, action: .view(.setMiniMode(false)))))
    }
    
    // Should sync to sensor node status
    await store.receive(\.sensorNodeStatus.view.setMiniMode)
  }
  
  func testTeardownAction() async {
    let store = TestStore(
      initialState: DashboardFeature.State(),
      reducer: { DashboardFeature() }
    )
    
    store.exhaustivity = .off(showSkippedAssertions: true)
    
    await store.send(.view(.teardown))
    
    // Should receive teardown actions for all monitoring items
    for id in store.state.monitoringItems.ids {
      await store.receive(.monitoringItems(.element(id: id, action: .view(.teardown))))
    }
    
    // Should receive teardown for sensor node status
    await store.receive(\.sensorNodeStatus.view.teardown)
  }
  
  func testMonitoringItemDataUpdated() async {
    let store = TestStore(
      initialState: DashboardFeature.State(),
      reducer: { DashboardFeature() }
    )
    
    let testId = ifstatOutputTopic
    
    await store.send(.monitoringItems(.element(id: testId, action: .delegate(.dataUpdated))))
    
    await store.receive(\.delegate.dataUpdated)
  }
  
  func testSensorStatusUpdated() async {
    let store = TestStore(
      initialState: DashboardFeature.State(),
      reducer: { DashboardFeature() }
    )
    
    await store.send(.sensorNodeStatus(.delegate(.statusUpdated)))
    
    await store.receive(\.delegate.dataUpdated)
  }
  
  func testIdentifiedArrayIntegration() async {
    let store = TestStore(
      initialState: DashboardFeature.State(),
      reducer: { DashboardFeature() }
    )
    
    // Test that we can access monitoring items by ID
    expectNoDifference(store.state.monitoringItems[id: ifstatOutputTopic]?.topicName, ifstatOutputTopic)
    expectNoDifference(store.state.monitoringItems[id: ifstatOutputTopic]?.displayName, "Network Speed")
    expectNoDifference(store.state.monitoringItems[id: ifstatOutputTopic]?.unit, "bytes/s")
    
    // Test CPU monitoring item
    expectNoDifference(store.state.monitoringItems[id: "monitoring/cpu"]?.displayName, "CPU Usage")
    expectNoDifference(store.state.monitoringItems[id: "monitoring/cpu"]?.unit, "%")
    
    // Test that all items have computed ID from topicName
    for item in store.state.monitoringItems {
      expectNoDifference(item.id, item.topicName)
    }
  }
  
  func testMiniModeInitialSync() async {
    // Test the bug fix: first drawer open shows correct mini mode
    let store = TestStore(
      initialState: DashboardFeature.State(isMiniMode: true),
      reducer: { DashboardFeature() }
    )
    
    store.exhaustivity = .off(showSkippedAssertions: true)
    
    // Simulate task action that should sync initial mini mode state
    await store.send(.view(.task))
    
    // Should receive sync actions for all monitoring items
    for id in store.state.monitoringItems.ids {
      await store.receive(.monitoringItems(.element(id: id, action: .view(.task))))
      await store.receive(.monitoringItems(.element(id: id, action: .view(.setMiniMode(true)))))
    }
    
    await store.receive(\.directVideoCall.view.task)
    await store.receive(\.sensorNodeStatus.view.task)
    await store.receive(\.sensorNodeStatus.view.setMiniMode)
    
    // After sync, all monitoring items should have isMiniMode = true
    for item in store.state.monitoringItems {
      expectNoDifference(item.isMiniMode, true)
    }
    expectNoDifference(store.state.sensorNodeStatus.isMiniMode, true)
  }
  
  func testGestureSelectionAndAutoReset() async {
    let clock = TestClock()
    
    let store = TestStore(
      initialState: DashboardFeature.State(currentRunningGesture: .idle),
      reducer: { DashboardFeature() }
    ) {
      $0.continuousClock = clock
    }
    
    // Test setting a gesture (not idle)
    await store.send(.view(.setRunningGesture(.emergencyStop))) {
      $0.currentRunningGesture = .emergencyStop
    }
    
    // Advance time by 2 seconds - should not reset yet
    await clock.advance(by: .seconds(2))
    
    // Advance time by 1 more second (total 3 seconds) - should auto-reset
    await clock.advance(by: .seconds(1))
    
    await store.receive(._internal(.resetToIdle)) {
      $0.currentRunningGesture = .idle
    }
  }
  
  func testGestureSelectionCancelsTimer() async {
    let clock = TestClock()
    
    let store = TestStore(
      initialState: DashboardFeature.State(currentRunningGesture: .idle),
      reducer: { DashboardFeature() }
    ) {
      $0.continuousClock = clock
    }
    
    // Set first gesture
    await store.send(.view(.setRunningGesture(.emergencyStop))) {
      $0.currentRunningGesture = .emergencyStop
    }
    
    // Advance time by 2 seconds
    await clock.advance(by: .seconds(2))
    
    // Set another gesture - should cancel previous timer and start new one
    await store.send(.view(.setRunningGesture(.followMe))) {
      $0.currentRunningGesture = .followMe
    }
    
    // Advance by 2 more seconds (4 total, but only 2 since last gesture)
    await clock.advance(by: .seconds(2))
    
    // Should not reset yet, advance 1 more second (3 since last gesture)
    await clock.advance(by: .seconds(1))
    
    await store.receive(._internal(.resetToIdle)) {
      $0.currentRunningGesture = .idle
    }
  }
  
  func testSettingIdleGestureCancelsTimer() async {
    let clock = TestClock()
    
    let store = TestStore(
      initialState: DashboardFeature.State(currentRunningGesture: .idle),
      reducer: { DashboardFeature() }
    ) {
      $0.continuousClock = clock
    }
    
    // Set non-idle gesture
    await store.send(.view(.setRunningGesture(.stop))) {
      $0.currentRunningGesture = .stop
    }
    
    // Advance time by 1 second
    await clock.advance(by: .seconds(1))
    
    // Manually set to idle - should cancel timer
    await store.send(.view(.setRunningGesture(.idle))) {
      $0.currentRunningGesture = .idle
    }
    
    // Advance time by 5 seconds - should not receive any reset action
    await clock.advance(by: .seconds(5))
  }
  
  func testShowSettings() async {
    let store = TestStore(
      initialState: DashboardFeature.State(),
      reducer: { DashboardFeature() }
    )
    
    await store.send(.view(.showSettings))
    // Settings action just logs - no state changes expected
  }
  
  func testSimulateAlert() async {
    let store = TestStore(
      initialState: DashboardFeature.State(),
      reducer: { DashboardFeature() }
    )
    
    // Test all alert types
    await store.send(.view(.simulateAlert(.green)))
    await store.receive(\.directVideoCall.view.simulateAlert)
    
    await store.send(.view(.simulateAlert(.yellow)))
    await store.receive(\.directVideoCall.view.simulateAlert)
    
    await store.send(.view(.simulateAlert(.red)))
    await store.receive(\.directVideoCall.view.simulateAlert)
    
    await store.send(.view(.simulateAlert(.none)))
    await store.receive(\.directVideoCall.view.simulateAlert)
  }
  
  func testAlertSimulationForwardingToDirectVideoCall() async {
    let store = TestStore(
      initialState: DashboardFeature.State(),
      reducer: { DashboardFeature() }
    )
    
    // Test that alert simulation is properly forwarded to DirectVideoCallFeature
    await store.send(.view(.simulateAlert(.red)))
    
    // Should receive the forwarded action with the correct alert type
    await store.receive(.directVideoCall(.view(.simulateAlert(.red))))
  }
}
