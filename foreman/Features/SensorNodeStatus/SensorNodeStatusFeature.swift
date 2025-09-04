//
//  SensorNodeStatusFeature.swift
//  foreman
//
//  Created by Claude on 2025/9/4.
//

import DequeModule
import ComposableArchitecture
import Foundation
import MqttClientKit
import MQTTNIO
import OSLog

// MARK: - MQTT Topics

let sensorNodeStatusTopic = "sensor_nodes/status" // Receive sensor node status data

// MARK: - Data Models

enum SensorNodeStatusValue: Int, Codable, Equatable, CaseIterable {
  case working = 0
  case degraded = 1
  case disconnected = 2
  
  var description: String {
    switch self {
    case .working: return "Working"
    case .degraded: return "Degraded"
    case .disconnected: return "Disconnected"
    }
  }
  
}

struct SensorNodeStatus: Codable, Equatable {
  let name: String
  let status: SensorNodeStatusValue
}

struct SensorNodesStatusMessage: Codable, Equatable {
  let sensorNodesStatus: [SensorNodeStatus]
  let timestamp: Date
  
  enum CodingKeys: String, CodingKey {
    case sensorNodesStatus = "sensor_nodes_status"
    case timestamp
  }
}

@Reducer
struct SensorNodeStatusFeature {
  @ObservableState
  struct State: Equatable {
    var sensorNodes: [SensorNodeStatus] = []
    var topicName: String = sensorNodeStatusTopic
    var displayName: String? = nil
    var lastUpdateTime: Date = .init()
    var lastError: String?
    
    // MQTT Subscriber Feature for handling sensor status data
    var mqttSubscriber: MqttSubscriberFeature.State = .init()
    
    // JSON Parser Feature for parsing sensor status data
    var parser: CodableParserFeature<SensorNodesStatusMessage>.State = .init()
    
    var latestMessage: SensorNodesStatusMessage? {
      guard !sensorNodes.isEmpty else { return nil }
      return SensorNodesStatusMessage(
        sensorNodesStatus: sensorNodes,
        timestamp: lastUpdateTime
      )
    }
    
    // Computed properties for easy access to specific sensor nodes
    var platformSensorStatus: SensorNodeStatus? {
      sensorNodes.first { $0.name == "platform_sensor_node" }
    }
    
    var telescopeSensorStatus: SensorNodeStatus? {
      sensorNodes.first { $0.name == "telescope_sensor_node" }
    }
    
    var turntableSensorStatus: SensorNodeStatus? {
      sensorNodes.first { $0.name == "turntable_sensor_node" }
    }
    
    var jibSensorStatus: SensorNodeStatus? {
      sensorNodes.first { $0.name == "jib_sensor_node" }
    }
    
  }
  
  @CasePathable
  enum Action: Equatable, BindableAction, ComposableArchitecture.ViewAction {
    case view(ViewAction)
    case binding(BindingAction<State>)
    case _internal(InternalAction)
    case delegate(DelegateAction)
    case mqttSubscriber(MqttSubscriberFeature.Action)
    case parser(CodableParserFeature<SensorNodesStatusMessage>.Action)
    
    @CasePathable
    enum ViewAction: Equatable {
      case task
      case teardown
      case clearError
    }
    
    @CasePathable
    enum InternalAction: Equatable {
      case sensorStatusUpdated(SensorNodesStatusMessage)
      case updateLastRefreshTime
    }
    
    @CasePathable
    enum DelegateAction: Equatable {
      case statusUpdated
    }
  }
  
  private enum CancelID {
    case mqttMessages
  }
  
  private let logger = Logger(subsystem: "foreman", category: "SensorNodeStatusFeature")
  
  var body: some ReducerOf<Self> {
    BindingReducer()
    Scope(state: \.mqttSubscriber, action: \.mqttSubscriber) {
      MqttSubscriberFeature()
    }
    Scope(state: \.parser, action: \.parser) {
      CodableParserFeature<SensorNodesStatusMessage>()
    }
    Reduce(core)
  }
  
  func core(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .binding:
      return .none
      
    case .view(let viewAction):
      return handleViewAction(into: &state, action: viewAction)
      
    case ._internal(let internalAction):
      return handleInternalAction(into: &state, action: internalAction)
      
    case .delegate:
      return .none
      
    case .mqttSubscriber(.delegate(let delegateAction)):
      return handleMqttSubscriberDelegate(into: &state, action: delegateAction)
      
    case .mqttSubscriber:
      return .none
      
    case .parser(.delegate(let delegateAction)):
      return handleParserDelegate(into: &state, action: delegateAction)
      
    case .parser:
      return .none
    }
  }
  
  private func handleViewAction(into state: inout State, action: Action.ViewAction) -> Effect<
    Action
  > {
    switch action {
    case .task:
      let topicName = state.topicName
      logger.info("🔄 SensorNodeStatusFeature: Starting realtime monitoring for topic: \(topicName)")
      // Subscribe to the configured topic with realtime updates
      return .run { send in
        await send(.mqttSubscriber(.view(.task)))
        await send(.mqttSubscriber(.view(.subscribe(
          MQTTSubscribeInfo(topicFilter: topicName, qos: .atLeastOnce)
        ))))
      }
      
    case .teardown:
      return .merge(
        .cancel(id: CancelID.mqttMessages)
      )
      
    case .clearError:
      state.lastError = nil
      return .none
    }
  }
  
  private func handleInternalAction(into state: inout State, action: Action.InternalAction)
    -> Effect<Action>
  {
    @Dependency(\.date) var date
    switch action {
    case .sensorStatusUpdated(let message):
      state.sensorNodes = message.sensorNodesStatus
      state.lastUpdateTime = message.timestamp
      
      return .send(.delegate(.statusUpdated))
      
    case .updateLastRefreshTime:
      // This helps keep UI responsive and updates relative time display
      return .none
    }
  }
  
  // MARK: - MQTT Subscriber Delegate Handling
  
  private func handleMqttSubscriberDelegate(
    into state: inout State, action: MqttSubscriberFeature.Action.Delegate) -> Effect<Action>
  {
    switch action {
    case .messageReceived(let message):
      guard message.topicName == state.topicName else {
        return .none
      }
      logger.info("📥 SensorNodeStatusFeature: Received message for topic: \(message.topicName)")
      if let data = message.payload.getData(at: 0, length: message.payload.readableBytes) {
        return .send(.parser(.parseData(data)))
      }
      return .none
      
    case .subscriptionAdded(let subscriptionInfo):
      logger.info("🜢 SensorNodeStatusFeature: Subscribed to topic: \(subscriptionInfo.topicFilter)")
      return .none
      
    case .subscriptionRemoved(let topic):
      logger.info("🟠 SensorNodeStatusFeature: Unsubscribed from topic: \(topic)")
      return .none
      
    case .errorOccurred(let error):
      logger.error("🔴 SensorNodeStatusFeature: MQTT Subscriber error: \(error)")
      return .none
    }
  }
  
  // MARK: - Parser Delegate Handling
  
  private func handleParserDelegate(
    into state: inout State, action: CodableParserFeature<SensorNodesStatusMessage>.Action.Delegate) -> Effect<Action>
  {
    switch action {
    case .parsed(let message):
      logger.info("✅ SensorNodeStatusFeature: Parsed sensor status data with \(message.sensorNodesStatus.count) sensors")
      return .send(._internal(.sensorStatusUpdated(message)))
      
    case .parsingFailed(let error):
      logger.error("❌ SensorNodeStatusFeature: Parsing failed: \(error)")
      state.lastError = error
      return .none
    }
  }
}