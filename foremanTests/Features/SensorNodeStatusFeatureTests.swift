//
//  SensorNodeStatusFeatureTests.swift
//  foremanTests
//
//  Created by Claude on 2025/9/4.
//

import ComposableArchitecture
import Foundation
import MqttClientKit
import NIOCore
import XCTest

@testable import foreman

@MainActor
final class SensorNodeStatusFeatureTests: XCTestCase {
  
  func testInitialState() {
    let store = TestStore(initialState: SensorNodeStatusFeature.State()) {
      SensorNodeStatusFeature()
    }
    
    let state = store.state
    expectNoDifference(state.sensorNodes, [])
    expectNoDifference(state.topicName, sensorNodeStatusTopic)
  }
  
  func testSensorNodeStatusParsing() async {
    let store = TestStore(initialState: SensorNodeStatusFeature.State()) {
      SensorNodeStatusFeature()
    }
    
    // Test data matching your provided format
    let testMessage = SensorNodesStatusMessage(
      sensorNodesStatus: [
        SensorNodeStatus(name: "platform_sensor_node", status: .working),
        SensorNodeStatus(name: "telescope_sensor_node", status: .working),
        SensorNodeStatus(name: "turntable_sensor_node", status: .degraded),
        SensorNodeStatus(name: "jib_sensor_node", status: .disconnected)
      ],
      timestamp: Date(timeIntervalSince1970: 1725456789.0)
    )
    
    await store.send(._internal(.sensorStatusUpdated(testMessage))) {
      $0.sensorNodes = testMessage.sensorNodesStatus
      $0.lastUpdateTime = testMessage.timestamp
    }
    
    await store.receive(\.delegate.statusUpdated)
    
    // Verify computed properties
    let finalState = store.state
    expectNoDifference(finalState.platformSensorStatus?.status, .working)
    expectNoDifference(finalState.telescopeSensorStatus?.status, .working)
    expectNoDifference(finalState.turntableSensorStatus?.status, .degraded)
    expectNoDifference(finalState.jibSensorStatus?.status, .disconnected)
  }
  
  func testAllSensorsWorking() async {
    let store = TestStore(initialState: SensorNodeStatusFeature.State()) {
      SensorNodeStatusFeature()
    }
    
    let workingMessage = SensorNodesStatusMessage(
      sensorNodesStatus: [
        SensorNodeStatus(name: "platform_sensor_node", status: .working),
        SensorNodeStatus(name: "telescope_sensor_node", status: .working),
        SensorNodeStatus(name: "turntable_sensor_node", status: .working),
        SensorNodeStatus(name: "jib_sensor_node", status: .working)
      ],
      timestamp: Date()
    )
    
    await store.send(._internal(.sensorStatusUpdated(workingMessage))) {
      $0.sensorNodes = workingMessage.sensorNodesStatus
      $0.lastUpdateTime = workingMessage.timestamp
    }
    
    await store.receive(\.delegate.statusUpdated)
    
    expectNoDifference(store.state.sensorNodes.count, 4)
    expectNoDifference(store.state.sensorNodes.allSatisfy { $0.status == .working }, true)
  }
  
  func testSensorStatusValueEnum() {
    // Test enum cases and descriptions
    expectNoDifference(SensorNodeStatusValue.working.rawValue, 0)
    expectNoDifference(SensorNodeStatusValue.degraded.rawValue, 1)
    expectNoDifference(SensorNodeStatusValue.disconnected.rawValue, 2)
    
    expectNoDifference(SensorNodeStatusValue.working.description, "Working")
    expectNoDifference(SensorNodeStatusValue.degraded.description, "Degraded")
    expectNoDifference(SensorNodeStatusValue.disconnected.description, "Disconnected")
  }
  
  func testJSONParsing() throws {
    // Test parsing your exact JSON format
    let jsonString = """
    {
      "sensor_nodes_status": [
        { "name": "platform_sensor_node", "status": 0 },
        { "name": "telescope_sensor_node", "status": 0 },
        { "name": "turntable_sensor_node", "status": 0 },
        { "name": "jib_sensor_node", "status": 0 }
      ],
      "timestamp": 1725456789
    }
    """
    
    let jsonData = jsonString.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    let decoded = try decoder.decode(SensorNodesStatusMessage.self, from: jsonData)
    
    expectNoDifference(decoded.sensorNodesStatus.count, 4)
    expectNoDifference(decoded.sensorNodesStatus[0].name, "platform_sensor_node")
    expectNoDifference(decoded.sensorNodesStatus[0].status, .working)
    expectNoDifference(decoded.timestamp, Date(timeIntervalSince1970: 1725456789))
  }
  
  func testJSONParsingWithTimestamp() throws {
    // Test parsing with timestamp field as required
    let jsonString = """
    {
      "sensor_nodes_status": [
        { "name": "platform_sensor_node", "status": 1 },
        { "name": "telescope_sensor_node", "status": 2 }
      ],
      "timestamp": 1725456789
    }
    """
    
    let jsonData = jsonString.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    let decoded = try decoder.decode(SensorNodesStatusMessage.self, from: jsonData)
    
    expectNoDifference(decoded.sensorNodesStatus.count, 2)
    expectNoDifference(decoded.sensorNodesStatus[0].status, .degraded)
    expectNoDifference(decoded.sensorNodesStatus[1].status, .disconnected)
    expectNoDifference(decoded.timestamp, Date(timeIntervalSince1970: 1725456789))
  }
  
  func testParserDelegate() async {
    let store = TestStore(initialState: SensorNodeStatusFeature.State()) {
      SensorNodeStatusFeature()
    }
    
    let testMessage = SensorNodesStatusMessage(
      sensorNodesStatus: [
        SensorNodeStatus(name: "platform_sensor_node", status: .working)
      ],
      timestamp: Date()
    )
    
    await store.send(.parser(.delegate(.parsed(testMessage))))
    
    await store.receive(._internal(.sensorStatusUpdated(testMessage))) {
      $0.sensorNodes = testMessage.sensorNodesStatus
      $0.lastUpdateTime = testMessage.timestamp
    }
    
    await store.receive(\.delegate.statusUpdated)
  }
  
  func testParsingError() async {
    let store = TestStore(initialState: SensorNodeStatusFeature.State()) {
      SensorNodeStatusFeature()
    }
    
    let errorMessage = "Invalid JSON format"
    
    await store.send(.parser(.delegate(.parsingFailed(errorMessage)))) {
      $0.lastError = errorMessage
    }
  }
}