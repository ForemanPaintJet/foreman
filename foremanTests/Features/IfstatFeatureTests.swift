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
      initialState: IfstatFeature.State(),
      reducer: { IfstatFeature() }
    )
    
    expectNoDifference(store.state.interfaceData, [])
    expectNoDifference(store.state.timeRange, 300) // 5 minutes
    expectNoDifference(store.state.lastError, nil)
    expectNoDifference(store.state.topicName, ifstatOutputTopic)
  }
  
  func testTaskAction() async {
    let store = TestStore(
      initialState: IfstatFeature.State(),
      reducer: { IfstatFeature() }
    )
    
    store.exhaustivity = .off(showSkippedAssertions: true)
      
    await store.send(.view(.task))
    
    await store.receive(\.mqttSubscriber.view.task)
  }
  
  func testChangeTimeRange() async {
    let mockData = IfstatMqttMessage(value: 100, timestamp: Date().addingTimeInterval(-3600))
    let store = TestStore(
      initialState: IfstatFeature.State(interfaceData: [mockData]),
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
      initialState: IfstatFeature.State(lastError: "Test error"),
      reducer: { IfstatFeature() }
    )
    
    await store.send(.view(.clearError)) {
      $0.lastError = nil
    }
  }
  
  func testParsingError() async {
    let store = TestStore(
      initialState: IfstatFeature.State(),
      reducer: { IfstatFeature() }
    )
    
    let errorMessage = "JSON parsing failed"
    await store.send(._internal(.parsingError(errorMessage))) {
      $0.lastError = errorMessage
    }
  }
  
  func testParseIfstatDataSuccess() async {
    let fixedDate = Date(timeIntervalSince1970: 1_726_000_000)
    
    let store = TestStore(initialState: IfstatFeature.State()) {
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
    
    await store.send(._internal(.parseIfstatData(validJson)))
    
    await store.receive(\._internal.interfaceDataUpdated) { state in
      state.lastRefreshTime = fixedDate
    }
    
    await store.receive(\.delegate.dataUpdated)
  }
  
  func testParseIfstatDataFailure() async {
    let store = TestStore(
      initialState: IfstatFeature.State(),
      reducer: { IfstatFeature() }
    )
    
    let invalidJson = "invalid json".data(using: .utf8)!
    
    store.exhaustivity = .off(showSkippedAssertions: true)
    
    await store.send(._internal(.parseIfstatData(invalidJson)))
    
    await store.receive(\._internal.parsingError) { state in
      state.lastError = "The data couldn’t be read because it isn’t in the correct format."
//      XCTAssertNotNil(state.lastError)
    }
  }
  
  func testInterfaceDataUpdated() async {
    let fixedDate = Date(timeIntervalSince1970: 1_726_000_000)
    
    let store = TestStore(initialState: IfstatFeature.State()) {
      IfstatFeature()
    } withDependencies: {
      $0.date = .init({
        fixedDate
      })
    }
    
    store.exhaustivity = .off(showSkippedAssertions: true)
    
    let newData = [IfstatMqttMessage(value: 100, timestamp: Date())]
    
    await store.send(._internal(.interfaceDataUpdated(newData))) { state in
      state.interfaceData = newData
      state.lastRefreshTime = fixedDate
    }
    
    await store.receive(\.delegate.dataUpdated)
  }
}
