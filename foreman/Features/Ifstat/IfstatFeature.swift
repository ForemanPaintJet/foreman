//
//  IfstatFeature.swift
//  foreman
//
//  Created by Claude on 2025/8/28.
//

import DequeModule
import ComposableArchitecture
import Foundation
import MqttClientKit
import MQTTNIO
import OSLog

// MARK: - MQTT Topics

let ifstatOutputTopic = "network/ifstat/data" // Receive ifstat data

// MARK: - MQTT Data Models

struct IfstatMqttMessage: Codable, Equatable {
    let value: Int
    let timestamp: Date
}

@Reducer
struct IfstatFeature {
    @ObservableState
    struct State: Equatable {
        var interfaceData: Deque<IfstatMqttMessage> = []
        var topicName: String = ""
        var displayName: String? = nil
        var unit: String = ""
        var timeRange: TimeInterval = 300 // 5 minutes default
        var windowSize: Int = 10 // Number of recent data points to keep in sliding window
        var lastRefreshTime: Date = .init()
        var lastError: String?

        // MQTT Subscriber Feature for handling ifstat data
        var mqttSubscriber: MqttSubscriberFeature.State = .init()
        
        // JSON Parser Feature for parsing ifstat data
        var parser: CodableParserFeature<IfstatMqttMessage>.State = .init()

        var latestData: IfstatMqttMessage? {
            interfaceData.last
        }
    }

    @CasePathable
    enum Action: Equatable, BindableAction, ComposableArchitecture.ViewAction {
        case view(ViewAction)
        case binding(BindingAction<State>)
        case _internal(InternalAction)
        case delegate(DelegateAction)
        case mqttSubscriber(MqttSubscriberFeature.Action)
        case parser(CodableParserFeature<IfstatMqttMessage>.Action)

        @CasePathable
        enum ViewAction: Equatable {
            case task
            case teardown
            case changeTimeRange(TimeInterval)
            case changeWindowSize(Int)
            case clearError
        }

        @CasePathable
        enum InternalAction: Equatable {
            case interfaceDataUpdated([IfstatMqttMessage])
            case updateLastRefreshTime
        }

        @CasePathable
        enum DelegateAction: Equatable {
            case dataUpdated
        }
    }

    private enum CancelID {
        case mqttMessages
    }

    private let logger = Logger(subsystem: "foreman", category: "IfstatFeature")

    var body: some ReducerOf<Self> {
        BindingReducer()
        Scope(state: \.mqttSubscriber, action: \.mqttSubscriber) {
            MqttSubscriberFeature()
        }
        Scope(state: \.parser, action: \.parser) {
            CodableParserFeature<IfstatMqttMessage>()
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
            logger.info("🔄 IfstatFeature: Starting realtime monitoring for topic: \(topicName)")
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

        case .changeTimeRange(let newRange):
            state.timeRange = newRange
            // Filter data based on new time range
            let cutoffTime = Date().addingTimeInterval(-newRange)
            state.interfaceData = Deque(state.interfaceData.filter { $0.timestamp >= cutoffTime })
            return .none

        case .changeWindowSize(let newSize):
            state.windowSize = max(1, newSize) // Ensure window size is at least 1
            // Trim data to new window size using Deque's efficient operations
            while state.interfaceData.count > state.windowSize {
                state.interfaceData.removeFirst()
            }
            return .none

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
        case .interfaceDataUpdated(let newData):
            state.interfaceData = mergeInterfaceData(existing: state.interfaceData, new: newData, windowSize: state.windowSize)
            state.lastRefreshTime = date.now

            return .send(.delegate(.dataUpdated))

        case .updateLastRefreshTime:
            // This helps keep UI responsive and updates relative time display
            return .none
        }
    }

    private func mergeInterfaceData(existing: Deque<IfstatMqttMessage>, new: [IfstatMqttMessage], windowSize: Int)
        -> Deque<IfstatMqttMessage>
    {
        var result = existing
        
        // Append new data with O(1) performance
        for message in new {
            result.append(message)
            
            // Remove old data to maintain sliding window size with O(1) performance
            if result.count > windowSize {
                result.removeFirst()
            }
        }
        
        return result
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
            logger.info("📥 IfstatFeature: Received message for topic: \(message.topicName)")
            if let data = message.payload.getData(at: 0, length: message.payload.readableBytes) {
                return .send(.parser(.parseData(data)))
            }
            return .none

        case .subscriptionAdded(let subscriptionInfo):
            logger.info("🜢 IfstatFeature: Subscribed to topic: \(subscriptionInfo.topicFilter)")
            return .none

        case .subscriptionRemoved(let topic):
            logger.info("🟠 IfstatFeature: Unsubscribed from topic: \(topic)")
            return .none

        case .errorOccurred(let error):
            logger.error("🔴 IfstatFeature: MQTT Subscriber error: \(error)")
            return .none
        }
    }

    // MARK: - Parser Delegate Handling
    
    private func handleParserDelegate(
        into state: inout State, action: CodableParserFeature<IfstatMqttMessage>.Action.Delegate) -> Effect<Action>
    {
        switch action {
        case .parsed(let message):
            logger.info("✅ IfstatFeature: Parsed data value: \(message.value)")
            return .send(._internal(.interfaceDataUpdated([message])))
            
        case .parsingFailed(let error):
            logger.error("❌ IfstatFeature: Parsing failed: \(error)")
            state.lastError = error
            return .none
        }
    }
}
