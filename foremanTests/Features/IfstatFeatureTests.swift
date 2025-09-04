//
//  IfstatFeatureTests.swift
//  foremanTests
//
//  Created by Claude on 2025/8/28.
//

import ComposableArchitecture
import MqttClientKit
import XCTest

@testable import foreman

@MainActor
final class IfstatFeatureTests: XCTestCase {
  func testInitialState() async {
    let store = TestStore(
      initialState: IfstatFeature.State(
        topicName: "test/topic",
        displayName: "Test Sensor",
        unit: "test-unit"
      ),
      reducer: { IfstatFeature() }
    )
    
    expectNoDifference(store.state.interfaceData, [])
    expectNoDifference(store.state.timeRange, 300) // 5 minutes
    expectNoDifference(store.state.lastError, nil)
    expectNoDifference(store.state.topicName, "test/topic")
    expectNoDifference(store.state.displayName, "Test Sensor")
    expectNoDifference(store.state.unit, "test-unit")
  }
  
  func testTaskAction() async {
    let store = TestStore(
      initialState: IfstatFeature.State(
        topicName: "test/topic",
        unit: "test-unit"
      ),
      reducer: { IfstatFeature() }
    )
    
    store.exhaustivity = .off(showSkippedAssertions: true)
      
    await store.send(.view(.task))
    
    await store.receive(\.mqttSubscriber.view.task)
  }
  
  func testChangeTimeRange() async {
    let mockData = IfstatMqttMessage(value: 100, timestamp: Date().addingTimeInterval(-3600))
    let store = TestStore(
      initialState: IfstatFeature.State(
        interfaceData: [mockData],
        topicName: "test/topic",
        unit: "test-unit"
      ),
      reducer: { IfstatFeature() }
    )
    
    
    await store.send(.view(.changeTimeRange(900))) {
      $0.timeRange = 900 // 15 minutes
      // Data older than 15 minutes should be filtered out
      $0.interfaceData = []
    }
  }
  
  func testClearError() async {
    let store = TestStore(
      initialState: IfstatFeature.State(
        topicName: "test/topic",
        unit: "test-unit",
        lastError: "Test error"
      ),
      reducer: { IfstatFeature() }
    )
    
    await store.send(.view(.clearError)) {
      $0.lastError = nil
    }
  }
  
  func testParsingError() async {
    let store = TestStore(
      initialState: IfstatFeature.State(
        topicName: "test/topic",
        unit: "test-unit"
      ),
      reducer: { IfstatFeature() }
    )
    
    let errorMessage = "JSON parsing failed"
    await store.send(.parser(.delegate(.parsingFailed(errorMessage)))) {
      $0.lastError = errorMessage
    }
  }
  
  func testParseIfstatDataSuccess() async {
    let fixedDate = Date(timeIntervalSince1970: 1_726_000_000)
    
    let store = TestStore(
      initialState: IfstatFeature.State(
        topicName: "test/topic",
        unit: "test-unit"
      )
    ) {
      IfstatFeature()
    } withDependencies: {
      $0.date = .init({
        fixedDate
      })
    }
    
    store.exhaustivity = .off(showSkippedAssertions: true)
    
    let validJson = """
    {
      "value": 42,
      "timestamp": 1699123456
    }
    """.data(using: .utf8)!
    
    await store.send(.parser(.parseData(validJson)))
    
    await store.receive(\.parser.delegate.parsed)
    
    await store.receive(\._internal.interfaceDataUpdated) { state in
      state.lastRefreshTime = fixedDate
    }
    
    await store.receive(\.delegate.dataUpdated)
  }
  
  func testParseIfstatDataFailure() async {
    let store = TestStore(
      initialState: IfstatFeature.State(
        topicName: "test/topic",
        unit: "test-unit"
      ),
      reducer: { IfstatFeature() }
    )
    
    let invalidJson = "invalid json".data(using: .utf8)!
    
    store.exhaustivity = .off(showSkippedAssertions: false)
    
    await store.send(.parser(.parseData(invalidJson)))
    
    await store.receive(\.parser.delegate.parsingFailed) { state in
      state.lastError = "The data couldn’t be read because it isn’t in the correct format."
    }
  }
  
  func testCustomInitialization() async {
    let store = TestStore(
      initialState: IfstatFeature.State(
        topicName: "network/custom/data",
        displayName: "Custom Network Monitor",
        unit: "MB/s"
      ),
      reducer: { IfstatFeature() }
    )
    
    expectNoDifference(store.state.displayName, "Custom Network Monitor")
    expectNoDifference(store.state.topicName, "network/custom/data")
    expectNoDifference(store.state.unit, "MB/s")
  }
  
  func testAutoDisplayName() async {
    let store = TestStore(
      initialState: IfstatFeature.State(
        topicName: "sensor/temperature",
        displayName: nil,
        unit: "°C"
      ),
      reducer: { IfstatFeature() }
    )
    
    expectNoDifference(store.state.displayName, nil)
    expectNoDifference(store.state.topicName, "sensor/temperature")
    expectNoDifference(store.state.unit, "°C")
  }
  
  func testLatestDataProperty() async {
    let fixedDate = Date(timeIntervalSince1970: 1_726_000_000)
    
    let store = TestStore(
      initialState: IfstatFeature.State(
        topicName: "test/topic",
        unit: "test-unit"
      )
    ) {
      IfstatFeature()
    } withDependencies: {
      $0.date = .init({ fixedDate })
    }
    
    // Initially no data
    expectNoDifference(store.state.latestData, nil)
    
    // Add first data point through internal action
    let firstData = IfstatMqttMessage(value: 100, timestamp: Date().addingTimeInterval(-60))
    await store.send(._internal(.interfaceDataUpdated([firstData]))) { state in
      state.interfaceData = [firstData]
      state.lastRefreshTime = fixedDate
    }
    await store.receive(\.delegate.dataUpdated)
    
    // Verify latest data is the first one
    expectNoDifference(store.state.latestData, firstData)
    
    // Add second data point - should become the latest
    let secondData = IfstatMqttMessage(value: 200, timestamp: Date())
    await store.send(._internal(.interfaceDataUpdated([secondData]))) { state in
      state.interfaceData = [firstData, secondData]
      state.lastRefreshTime = fixedDate
    }
    await store.receive(\.delegate.dataUpdated)
    
    // Verify latest data is now the second one (last in queue)
    expectNoDifference(store.state.latestData, secondData)
  }
}
