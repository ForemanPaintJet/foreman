//
//  WebRTCMqttFeature.swift
//  foreman
//
//  Created by Jed Lu on 2025/7/18.
//

import Combine
import ComposableArchitecture
import Foundation
import MqttClientKit
import MQTTNIO
import NIOCore
import OSLog
import SwiftUI

// MARK: - WebRTC MQTT Feature

let inputTopic = "camera_system/streaming/in"
let outputTopic = "camera_system/streaming/out"

@Reducer
struct WebRTCMqttFeature {
    @ObservableState
    struct State: Equatable {
        enum LoadingItem: String, Equatable, CaseIterable {
            case connecting
            case joiningRoom
            case leavingRoom
            case sendingOffer
            case sendingAnswer
            case sendingIceCandidate
        }

        var loadingItems: Set<LoadingItem> = []
        var connectionStatus: MqttClientKit.State = .idle
        var mqttInfo: MqttClientKitInfo = .init(
            address: "192.168.1.124", port: 1883, clientID: "")

        var userId: String = ""
        var connectedUsers: [String] = []
        var lastError: String?
        var messages: [MQTTPublishInfo] = []
        var isJoinedToRoom: Bool = false

        // WebRTC specific state
        var pendingOffers: [WebRTCOffer] = []
        var pendingAnswers: [WebRTCAnswer] = []
        var pendingIceCandidates: [ICECandidate] = []

        @Presents var alert: AlertState<Action.Alert>?

        mutating func generateDefaultUserId() {
            userId = "user_\(UUID().uuidString.prefix(8))"
            mqttInfo.clientID = userId
        }
    }

    @CasePathable
    enum Action: Equatable, BindableAction, ComposableArchitecture.ViewAction {
        case view(ViewAction)
        case binding(BindingAction<State>)
        case _internal(InternalAction)
        case delegate(DelegateAction)
        case alert(PresentationAction<Alert>)

        @CasePathable
        enum ViewAction: Equatable {
            case task
            case teardown
            case connectToBroker
            case disconnect
            case joinRoom
            case leaveRoom
            case sendOffer(to: String, sdp: String)
            case sendAnswer(to: String, sdp: String)
            case sendIceCandidate(
                to: String, candidate: String, sdpMLineIndex: Int, sdpMid: String?)
            case clearMessages
            case clearError

            // WebRTC Actions
            case createOfferForUser(String)
        }

        @CasePathable
        enum InternalAction: Equatable {
            case setLoading(State.LoadingItem, Bool)
            case connectionStatusChanged(MqttClientKit.State)
            case mqttMessageReceived(MQTTPublishInfo)
            case offerReceived(WebRTCOffer)
            case answerReceived(WebRTCAnswer)
            case iceCandidateReceived(ICECandidate)
            case roomUpdateReceived(RoomInfo)
            case errorOccurred(String)
            case mqttConnected
            case mqttDisconnected
            case roomJoined
            case roomLeft

            // WebRTC Internal Actions
            case webRTCOfferGenerated(WebRTCOffer)
            case webRTCAnswerGenerated(WebRTCAnswer)
            case webRTCIceCandidateGenerated(ICECandidate)
            case peerConnectionCreated(String)
            case peerConnectionRemoved(String)
        }

        enum DelegateAction: Equatable {
            case didConnect
            case didDisconnect
            case didJoinRoom(String)
            case didLeaveRoom
            case didReceiveOffer(WebRTCOffer)
            case didReceiveAnswer(WebRTCAnswer)
            case didReceiveIceCandidate(ICECandidate)
            case connectionError(String)
        }

        enum Alert: Equatable {
            case confirmDisconnect
            case confirmLeaveRoom
            case dismissError
        }
    }

    private enum CancelID {
        case state
        case message
        case stream
    }

    private let logger = Logger(subsystem: "foreman", category: "WebRTCMqttFeature")

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce(core)
            .ifLet(\.$alert, action: \.alert)
    }

    func core(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .binding(\.userId):
            state.mqttInfo.clientID = state.userId
            return .none
        case .binding:
            return .none

        case .view(let viewAction):
            return handleViewAction(into: &state, action: viewAction)

        case ._internal(let internalAction):
            return handleInternalAction(into: &state, action: internalAction)

        case .delegate:
            return .none

        case .alert(.presented(.confirmDisconnect)):
            return executeDisconnect(state: &state)

        case .alert(.presented(.confirmLeaveRoom)):
            return .send(.view(.leaveRoom))

        case .alert(.presented(.dismissError)):
            state.lastError = nil
            return .none

        case .alert(.dismiss):
            return .none
        }
    }

    private func handleViewAction(into state: inout State, action: Action.ViewAction) -> Effect<
        Action
    > {
        @Dependency(\.mqttClientKit) var mqttClientKit
        @Dependency(\.webRTCClient) var webRTCClient

        switch action {
        case .task:
            logger.info(
                "🟠 [WebRTCMqttFeature] task: Generating default userId and subscribing to streams")
            state.generateDefaultUserId()
            return .run { send in
                // Subscribe to MQTT streams
                await withTaskGroup(of: Void.self) { group in
                    // WebRTC streams
                    group.addTask {
                        for await offer in await webRTCClient.offerStream() {
                            await send(._internal(.webRTCOfferGenerated(offer)))
                        }
                    }
                    group.addTask {
                        for await answer in await webRTCClient.answerStream() {
                            await send(._internal(.webRTCAnswerGenerated(answer)))
                        }
                    }
                    group.addTask {
                        for await candidate in await webRTCClient.iceCandidateStream() {
                            await send(._internal(.webRTCIceCandidateGenerated(candidate)))
                        }
                    }
                }
            }
            .cancellable(id: CancelID.stream)

        case .teardown:
            return .cancel(id: CancelID.stream)

        case .connectToBroker:
            guard
                !state.mqttInfo.address.isEmpty,
                !state.userId.isEmpty
            else {
                return .send(
                    ._internal(
                        .errorOccurred("MQTT address, Room ID, and User ID are required")))
            }
            let info = state.mqttInfo

            logger.info(
                "🟠 [MQTT] Connecting to broker: address=\(info.address), port=\(info.port), clientID=\(info.clientID)"
            )

            return .run { send in
                await send(._internal(.setLoading(.connecting, true)))
                let stream = await mqttClientKit.connect(info)
                await send(._internal(.mqttConnected))
                await send(.delegate(.didConnect))

                for await status in stream {
                    await send(._internal(.connectionStatusChanged(status)))
                }

            }.cancellable(id: CancelID.state)
        case .disconnect:
            return executeDisconnect(state: &state)

        case .joinRoom:
            guard !state.userId.isEmpty else {
                return .send(._internal(.errorOccurred("Room ID and User ID are required")))
            }
            guard state.connectionStatus == .connected else {
                return .send(._internal(.errorOccurred("Not connected to MQTT broker")))
            }
            let userId = state.userId
            logger.info("🟠 [MQTT] userId=\(userId)")

            // Implement room join logic via MQTT topic subscription
            return .run { send in
                await send(._internal(.setLoading(.joiningRoom, true)))
                do {
                    let subInfo = MQTTSubscribeInfo(
                        topicFilter: outputTopic, qos: .atLeastOnce)
                    _ = try await mqttClientKit.subscribe(subInfo)

                    let msg = RequestVideoMessage(clientId: userId, videoSource: "")
                    let payload = try JSONEncoder().encode(msg)
                    let requestInfo = MQTTPublishInfo(
                        qos: .exactlyOnce, retain: false, topicName: inputTopic,
                        payload: ByteBuffer(data: payload), properties: [])

                    try await mqttClientKit.publish(requestInfo)

                    await send(._internal(.roomJoined))
                    await send(.delegate(.didJoinRoom("")))
                } catch {
                    await send(._internal(.errorOccurred(error.localizedDescription)))
                }
                await send(._internal(.setLoading(.joiningRoom, false)))
            }

        case .leaveRoom:
            //                logger.info("🟠 [MQTT] Leaving room: \(state.roomId)")
            guard state.isJoinedToRoom else { return .none }
            return .run { send in
                await send(._internal(.setLoading(.leavingRoom, true)))
                do {
                    try await mqttClientKit.unsubscribe(outputTopic)
                    let msg = LeaveVideoMessage(clientId: "123", videoSource: "")
                    let payload = try JSONEncoder().encode(msg)
                    let requestInfo = MQTTPublishInfo(
                        qos: .exactlyOnce, retain: false, topicName: inputTopic,
                        payload: ByteBuffer(data: payload), properties: [])
                    try await mqttClientKit.publish(requestInfo)

                    await send(._internal(.roomLeft))
                    await send(.delegate(.didLeaveRoom))
                } catch {
                    await send(._internal(.errorOccurred(error.localizedDescription)))
                }
                await send(._internal(.setLoading(.leavingRoom, false)))
            }

        case .sendOffer(let to, let sdp):
            logger.info("🟠 [WebRTC] Sending offer to: \(to), sdp length: \(sdp.count)")
            // Publish offer to MQTT topic
            let offer = WebRTCOffer(
                sdp: sdp, type: "offer", clientId: state.userId, videoSource: "")
            return .run { send in
                await send(._internal(.setLoading(.sendingOffer, true)))
                do {
                    let payload = try JSONEncoder().encode(offer)
                    let info = MQTTPublishInfo(
                        qos: .atLeastOnce, retain: false, topicName: inputTopic,
                        payload: ByteBuffer(data: payload), properties: .init([]))
                    try await mqttClientKit.publish(info)
                } catch {
                    await send(._internal(.errorOccurred(error.localizedDescription)))
                }
                await send(._internal(.setLoading(.sendingOffer, false)))
            }

        case .sendAnswer(let to, let sdp):
            logger.info("🟠 [WebRTC] Sending answer to: \(to), sdp length: \(sdp.count)")
            let answer = WebRTCAnswer(
                sdp: sdp, type: "answer", clientId: state.userId, videoSource: "")
            return .run { send in
                await send(._internal(.setLoading(.sendingAnswer, true)))
                do {
                    let payload = try JSONEncoder().encode(answer)
                    let info = MQTTPublishInfo(
                        qos: .atLeastOnce, retain: false, topicName: inputTopic,
                        payload: ByteBuffer(data: payload), properties: .init([]))
                    try await mqttClientKit.publish(info)
                } catch {
                    await send(._internal(.errorOccurred(error.localizedDescription)))
                }
                await send(._internal(.setLoading(.sendingAnswer, false)))
            }

        case .sendIceCandidate(let to, let candidate, let sdpMLineIndex, let sdpMid):
            logger.info(
                "🟠 [WebRTC] Sending ICE candidate to: \(to), candidate: \(candidate.prefix(20))..."
            )
            let iceCandidate = ICECandidate(
                type: "ice", clientId: state.userId,
                candidate: .init(candidate: candidate, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid))
            return .run { send in
                await send(._internal(.setLoading(.sendingIceCandidate, true)))
                do {
                    let payload = try JSONEncoder().encode(iceCandidate)
                    let info = MQTTPublishInfo(
                        qos: .atLeastOnce, retain: false, topicName: inputTopic,
                        payload: ByteBuffer(data: payload), properties: .init([]))
                    try await mqttClientKit.publish(info)
                } catch {
                    await send(._internal(.errorOccurred(error.localizedDescription)))
                }
                await send(._internal(.setLoading(.sendingIceCandidate, false)))
            }

        case .clearMessages:
            state.messages = []
            return .none

        case .clearError:
            state.lastError = nil
            return .none

        case .createOfferForUser(let userId):
            return .run { send in
                do {
                    let created = await webRTCClient.createPeerConnection(userId)
                    if created {
                        await send(._internal(.peerConnectionCreated(userId)))
                    }
                    try await webRTCClient.createOffer(userId)
                } catch {
                    await send(
                        ._internal(
                            .errorOccurred(
                                "Failed to create offer: \(error.localizedDescription)")))
                }
            }
        }
    }

    private func handleInternalAction(into state: inout State, action: Action.InternalAction)
        -> Effect<Action>
    {
        @Dependency(\.mqttClientKit) var mqttClientKit
        @Dependency(\.webRTCClient) var webRTCClient

        switch action {
        case .setLoading(let item, let isLoading):
            if isLoading {
                state.loadingItems.insert(item)
            } else {
                state.loadingItems.remove(item)
            }
            return .none

        case .connectionStatusChanged(let status):
            state.connectionStatus = status
            return .none

        case .mqttMessageReceived(let message):
            logger.info(
                "🟠 [MQTT] Message received: topic=\(message.topicName), payload=\(message.payload.readableBytes) bytes"
            )
            state.messages.append(message)
            if state.messages.count > 50 {
                state.messages.removeFirst()
            }

            // Parse message and dispatch to appropriate internal action
            if let data = message.payload.getData(at: 0, length: message.payload.readableBytes) {
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    if let json = json, let type = json["type"] as? String,
                       let clientId = json["clientId"] as? String
                    {
                        switch type {
                        case "offer":
                            if let sdp = json["sdp"] as? String {
                                let offer = WebRTCOffer(
                                    sdp: sdp, type: type, clientId: clientId, videoSource: "")
                                logger.info("🟠 [MQTT] Parsed offer message")
                                if clientId == "self" {
                                    logger.info("Ignore \(clientId) message.")
                                    return .none
                                }
                                return .send(._internal(.offerReceived(offer)))
                            }
                        case "answer":
                            if let sdp = json["sdp"] as? String {
                                let answer = WebRTCAnswer(
                                    sdp: sdp, type: type, clientId: clientId, videoSource: "")
                                logger.info("🟠 [MQTT] Parsed answer message")
                                if clientId == "self" {
                                    logger.info("Ignore \(clientId) message.")
                                    return .none
                                }
                                return .send(._internal(.answerReceived(answer)))
                            }
                        case "ice":
                            if let candidateObj = json["candidate"] as? [String: Any],
                               let candidate = candidateObj["candidate"] as? String,
                               let sdpMLineIndex = candidateObj["sdpMLineIndex"] as? Int
                            {
                                let sdpMid: String? = candidateObj["sdpMid"] as? String
                                let ice = ICECandidate(
                                    type: type, clientId: clientId,
                                    candidate: .init(
                                        candidate: candidate, sdpMLineIndex: sdpMLineIndex,
                                        sdpMid: sdpMid))
                                logger.info("🟠 [MQTT] Parsed ICE message")
                                if clientId == "self" {
                                    logger.info("Ignore \(clientId) message.")
                                    return .none
                                }
                                return .send(._internal(.iceCandidateReceived(ice)))
                            }
                        case "requestVideo":
                            logger.info(
                                "🟠 [MQTT] Received requestVideo message from clientId=\(clientId)"
                            )
                            // You can add handling logic here if needed
                            return .none
                        case "leaveVideo":
                            logger.info(
                                "🟠 [MQTT] Received leaveVideo message from clientId=\(clientId)"
                            )
                            // You can add handling logic here if needed
                            return .none
                        default:
                            logger.info("🟠 [MQTT] Unrecognized type: \(type)")
                            return .none
                        }
                    }
                } catch {
                    logger.error("🔴 [MQTT] Failed to parse MQTT message payload: \(error)")
                }
            }
            logger.info("🟠 [MQTT] Unrecognized MQTT message payload")
            return .none

        case .offerReceived(let offer):
            logger.info(
                "🟠 [WebRTC] Offer received: from=\(offer.clientId), sdp length=\(offer.sdp.count)"
            )
            state.pendingOffers.append(offer)
            return .run { send in
                do {
                    try await webRTCClient.handleRemoteOffer(offer)
                } catch {
                    await send(
                        ._internal(
                            .errorOccurred(
                                "Failed to handle remote offer: \(error.localizedDescription)"))
                    )
                }
            }

        case .answerReceived(let answer):
            logger.info(
                "🟠 [WebRTC] Answer received: from=\(answer.clientId), sdp length=\(answer.sdp.count)"
            )
            state.pendingAnswers.append(answer)
            return .run { send in
                do {
                    try await webRTCClient.handleRemoteAnswer(answer)
                } catch {
                    await send(
                        ._internal(
                            .errorOccurred(
                                "Failed to handle remote answer: \(error.localizedDescription)")
                        ))
                }
            }

        case .iceCandidateReceived(let candidate):
            logger.info(
                "🟠 [WebRTC] ICE candidate received: from=\(candidate.clientId), candidate=\(candidate.candidate.candidate.prefix(20))..."
            )
            state.pendingIceCandidates.append(candidate)
            return .run { send in
                do {
                    try await webRTCClient.handleRemoteIceCandidate(candidate)
                } catch {
                    await send(
                        ._internal(
                            .errorOccurred(
                                "Failed to handle remote ICE candidate: \(error.localizedDescription)"
                            )))
                }
            }

        case .roomUpdateReceived(let roomInfo):
            logger.info("🟠 [MQTT] Room update received: users=\(roomInfo.users)")
            state.connectedUsers = roomInfo.users
            return .none

        case .errorOccurred(let error):
            logger.error("🔴 [WebRTCMqttFeature] Error occurred: \(error)")
            state.lastError = error
            return .send(.delegate(.connectionError(error)))

        case .mqttConnected:
            logger.info("🟢 [MQTT] MQTT Connected")
            state.connectionStatus = .connected
            state.lastError = nil
            return .run { send in
                do {
                    for try await message in mqttClientKit.received() {
                        await send(._internal(.mqttMessageReceived(message)))
                    }
                } catch {
                    await send(._internal(.errorOccurred(error.localizedDescription)))
                }
            }.cancellable(id: CancelID.message)

        case .mqttDisconnected:
            logger.info("🟠 [MQTT] MQTT Disconnected")
            state.connectionStatus = .disconnected(.noConnection)
            state.isJoinedToRoom = false
            state.connectedUsers = []
            return .none

        case .roomJoined:
            logger.info("🟢 [MQTT] Room joined")
            state.isJoinedToRoom = true
            return .none

        case .roomLeft:
            logger.info("🟠 [MQTT] Room left")
            state.isJoinedToRoom = false
            let connectedUsers = state.connectedUsers
            state.connectedUsers = []
            return .run { send in
                for userId in connectedUsers {
                    await webRTCClient.removePeerConnection(userId)
                    await send(._internal(.peerConnectionRemoved(userId)))
                }
            }

        // WebRTC Internal Actions
        case .webRTCOfferGenerated(let offer):
            return .run { send in
                do {
                    let payload = try JSONEncoder().encode(offer)
                    let info = MQTTPublishInfo(
                        qos: .atLeastOnce, retain: false, topicName: inputTopic,
                        payload: ByteBuffer(data: payload), properties: .init([]))
                    try await mqttClientKit.publish(info)
                } catch {
                    await send(
                        ._internal(
                            .errorOccurred(
                                "Failed to send offer: \(error.localizedDescription)")))
                }
            }

        case .webRTCAnswerGenerated(let answer):
            return .run { send in
                do {
                    let payload = try JSONEncoder().encode(answer)
                    let info = MQTTPublishInfo(
                        qos: .atLeastOnce, retain: false, topicName: inputTopic,
                        payload: ByteBuffer(data: payload), properties: .init([]))
                    try await mqttClientKit.publish(info)
                } catch {
                    await send(
                        ._internal(
                            .errorOccurred(
                                "Failed to send answer: \(error.localizedDescription)")))
                }
            }

        case .webRTCIceCandidateGenerated(let candidate):
            return .run { send in
                do {
                    let payload = try JSONEncoder().encode(candidate)
                    let info = MQTTPublishInfo(
                        qos: .atLeastOnce, retain: false, topicName: inputTopic,
                        payload: ByteBuffer(data: payload), properties: .init([]))
                    try await mqttClientKit.publish(info)
                } catch {
                    await send(
                        ._internal(
                            .errorOccurred(
                                "Failed to send ICE candidate: \(error.localizedDescription)")))
                }
            }

        case .peerConnectionCreated(let userId):
            return .none

        case .peerConnectionRemoved(let userId):
            return .none
        }
    }

    // MARK: - Helper Functions

    private func executeDisconnect(state: inout State) -> Effect<Action> {
        let connectedUsers = state.connectedUsers
        let isJoinedToRoom = state.isJoinedToRoom

        @Dependency(\.mqttClientKit) var mqttClientKit
        @Dependency(\.webRTCClient) var webRTCClient

        return .run { send in
            do {
                if isJoinedToRoom {
                    await send(._internal(.setLoading(.leavingRoom, true)))
                    try await mqttClientKit.unsubscribe(outputTopic)
                    await send(._internal(.roomLeft))
                    await send(.delegate(.didLeaveRoom))
                    await send(._internal(.setLoading(.leavingRoom, false)))
                    for userId in connectedUsers {
                        await webRTCClient.removePeerConnection(userId)
                        await send(._internal(.peerConnectionRemoved(userId)))
                    }
                }
                try await mqttClientKit.disconnect()
                await send(._internal(.mqttDisconnected))
                await send(.delegate(.didDisconnect))
            } catch {
                await send(._internal(.errorOccurred(error.localizedDescription)))
            }
        }
    }
}
