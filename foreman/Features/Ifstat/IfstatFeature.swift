//
//  IfstatFeature.swift
//  foreman
//
//  Created by Claude on 2025/8/28.
//

import ComposableArchitecture
import Foundation
import MQTTNIO
import MqttClientKit
import OSLog

// MARK: - MQTT Topics

let ifstatOutputTopic = "network/ifstat/data"  // Receive ifstat data

// MARK: - MQTT Data Models

struct IfstatMqttMessage: Codable, Equatable {
    let value: Int
    let timestamp: Date
}

@Reducer
struct IfstatFeature {
    @ObservableState
    struct State: Equatable {
        var interfaceData: [IfstatMqttMessage] = []
        var topicName: String = ifstatOutputTopic  // MQTT topic name used as view name
        var timeRange: TimeInterval = 300  // 5 minutes default
        var lastRefreshTime: Date = Date()

        // MQTT Subscriber Feature for handling ifstat data
        var mqttSubscriber: MqttSubscriberFeature.State = MqttSubscriberFeature.State()

        var latestData: IfstatMqttMessage? {
            interfaceData.first
        }
    }

    @CasePathable
    enum Action: Equatable, BindableAction, ComposableArchitecture.ViewAction {
        case view(ViewAction)
        case binding(BindingAction<State>)
        case _internal(InternalAction)
        case delegate(DelegateAction)
        case mqttSubscriber(MqttSubscriberFeature.Action)

        @CasePathable
        enum ViewAction: Equatable {
            case task
            case teardown
            case changeTimeRange(TimeInterval)
        }

        @CasePathable
        enum InternalAction: Equatable {
            case interfaceDataUpdated([IfstatMqttMessage])
            case parseIfstatData(Data)
            case updateLastRefreshTime
        }

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
        }
    }

    private func handleViewAction(into state: inout State, action: Action.ViewAction) -> Effect<
        Action
    > {
        switch action {
        case .task:
            logger.info("🔄 IfstatFeature: Starting realtime ifstat monitoring")
            // Subscribe to ifstat output topic with realtime updates
            return .merge(
                .send(
                    .mqttSubscriber(
                        .view(
                            .subscribe(
                                MQTTSubscribeInfo(topicFilter: ifstatOutputTopic, qos: .atLeastOnce))))),
                // Start realtime update timer
            )

        case .teardown:
            return .merge(
                .cancel(id: CancelID.mqttMessages)
            )

        case .changeTimeRange(let newRange):
            state.timeRange = newRange
            // Filter data based on new time range
            let cutoffTime = Date().addingTimeInterval(-newRange)
            state.interfaceData = state.interfaceData.filter { $0.timestamp >= cutoffTime }
            return .none
        }
    }

    private func handleInternalAction(into state: inout State, action: Action.InternalAction)
        -> Effect<Action>
    {
        switch action {
        case .interfaceDataUpdated(let newData):
            state.interfaceData = mergeInterfaceData(existing: state.interfaceData, new: newData)
            state.lastRefreshTime = Date()
            
            // Keep only data within current time range for realtime performance
            let cutoffTime = Date().addingTimeInterval(-state.timeRange)
            state.interfaceData = state.interfaceData.filter { $0.timestamp >= cutoffTime }
            
            return .send(.delegate(.dataUpdated))

        case .parseIfstatData(let data):
            return parseIfstatJsonData(data)
            
        case .updateLastRefreshTime:
            // This helps keep UI responsive and updates relative time display
            return .none
        }
    }

    private func mergeInterfaceData(existing: [IfstatMqttMessage], new: [IfstatMqttMessage])
        -> [IfstatMqttMessage]
    {
        // For realtime performance, keep more recent data and limit total points
        let maxDataPoints = 200  // Increased for better chart resolution
        let combined = existing + new
        
        // Sort by timestamp (newest first) and take only recent data points
        return Array(combined.sorted { $0.timestamp > $1.timestamp }.prefix(maxDataPoints))
    }

    // MARK: - MQTT Subscriber Delegate Handling

    private func handleMqttSubscriberDelegate(
        into state: inout State, action: MqttSubscriberFeature.Action.Delegate
    ) -> Effect<Action> {
        switch action {
        case .messageReceived(let message):
            guard message.topicName == ifstatOutputTopic else {
                return .none
            }
            logger.info("📥 IfstatFeature: Received ifstat message")
            if let data = message.payload.getData(at: 0, length: message.payload.readableBytes) {
                return .send(._internal(.parseIfstatData(data)))
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

    // MARK: - MQTT Helper Methods

    private func parseIfstatJsonData(_ data: Data) -> Effect<Action> {
        return .run { send in
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .secondsSince1970

                let mqttMessage = try decoder.decode(IfstatMqttMessage.self, from: data)
                logger.info("✅ IfstatFeature: Parsed data value: \(mqttMessage.value)")

                await send(._internal(.interfaceDataUpdated([mqttMessage])))
            } catch {
                logger.error("❌ IfstatFeature: JSON parsing failed: \(error)")
            }
        }
    }

}
