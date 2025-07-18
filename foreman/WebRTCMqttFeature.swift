//
//  WebRTCMqttFeature.swift
//  foreman
//
//  Created by Jed Lu on 2025/7/18.
//

import Combine
import ComposableArchitecture
import Foundation
import Logging
import MqttClientKit
import MQTTNIO
import NIOCore
import SwiftUI

extension MqttClientKitInfo: @retroactive Equatable {
    public static func == (lhs: MqttClientKitInfo, rhs: MqttClientKitInfo) -> Bool {
        true
    }
}

// MARK: - WebRTC MQTT Feature

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
            address: "127.0.0.1", port: 1883, clientID: "")
        var roomId: String = "webrtc/room/test-room"
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

    enum Action: TCAFeatureAction {
        @CasePathable
        enum ViewAction: Equatable {
            case onAppear
            case onDisappear
            case updateMqttAddress(String)
            case updateMqttPort(Int)
            case updateRoomId(String)
            case updateUserId(String)
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

        case view(ViewAction)
        case _internal(InternalAction)
        case delegate(DelegateAction)
        case alert(PresentationAction<Alert>)
    }

    private enum CancelID {
        case state
        case message
        case stream
    }

    @Dependency(\.mqttClientKit) var mqttClientKit
    @Dependency(\.webRTCClient) var webRTCClient

    // SwiftLog logger instance
    private let logger = Logger(label: "WebRTCMqttFeature")

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            logger.info("🟠 [WebRTCMqttFeature] Action: \(String(describing: action))")
            switch action {
            case .view(.onAppear):
                logger.info(
                    "🟠 [WebRTCMqttFeature] onAppear: Generating default userId and subscribing to streams"
                )
                state.generateDefaultUserId()
                let info = state.mqttInfo
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

            case .view(.onDisappear):
                return .cancel(id: CancelID.stream)

            case .view(.updateMqttAddress(let address)):
                state.mqttInfo.address = address
                return .none

            case .view(.updateMqttPort(let port)):
                state.mqttInfo.port = port
                return .none

            case .view(.updateRoomId(let roomId)):
                state.roomId = roomId
                return .none

            case .view(.updateUserId(let userId)):
                state.userId = userId
                state.mqttInfo.clientID = userId
                return .none

            case .view(.connectToBroker):
                logger.info(
                    "🟠 [MQTT] Connecting to broker: address=\(state.mqttInfo.address), port=\(state.mqttInfo.port), clientID=\(state.mqttInfo.clientID)"
                )
                guard
                    !state.mqttInfo.address.isEmpty, !state.roomId.isEmpty,
                    !state.userId.isEmpty
                else {
                    return .send(
                        ._internal(
                            .errorOccurred("MQTT address, Room ID, and User ID are required")))
                }
                let info = state.mqttInfo

                return .run { send in
                    await send(._internal(.setLoading(.connecting, true)))
                    let stream = await mqttClientKit.connect(info)
                    await send(._internal(.mqttConnected))
                    await send(.delegate(.didConnect))

                    for await status in stream {
                        await send(._internal(.connectionStatusChanged(status)))
                    }

                }.cancellable(id: CancelID.state)
            case .view(.disconnect):
                return executeDisconnect(state: &state)

            case .view(.joinRoom):
                logger.info("🟠 [MQTT] Joining room: \(state.roomId) as userId=\(state.userId)")
                guard !state.roomId.isEmpty, !state.userId.isEmpty else {
                    return .send(._internal(.errorOccurred("Room ID and User ID are required")))
                }
                guard state.connectionStatus == .connected else {
                    return .send(._internal(.errorOccurred("Not connected to MQTT broker")))
                }
                let roomId = state.roomId
                // Implement room join logic via MQTT topic subscription
                return .run { send in
                    await send(._internal(.setLoading(.joiningRoom, true)))
                    do {
                        let subInfo = MQTTSubscribeInfo(
                            topicFilter: roomId, qos: .atLeastOnce)
                        _ = try await mqttClientKit.subscribe(subInfo)
                        await send(._internal(.roomJoined))
                        await send(.delegate(.didJoinRoom(roomId)))
                    } catch {
                        await send(._internal(.errorOccurred(error.localizedDescription)))
                    }
                    await send(._internal(.setLoading(.joiningRoom, false)))
                }

            case .view(.leaveRoom):
                logger.info("🟠 [MQTT] Leaving room: \(state.roomId)")
                guard state.isJoinedToRoom else { return .none }
                let roomId = state.roomId
                return .run { send in
                    await send(._internal(.setLoading(.leavingRoom, true)))
                    do {
                        try await mqttClientKit.unsubscribe(roomId)
                        await send(._internal(.roomLeft))
                        await send(.delegate(.didLeaveRoom))
                    } catch {
                        await send(._internal(.errorOccurred(error.localizedDescription)))
                    }
                    await send(._internal(.setLoading(.leavingRoom, false)))
                }

            case .view(.sendOffer(let to, let sdp)):
                logger.info("🟠 [WebRTC] Sending offer to: \(to), sdp length: \(sdp.count)")
                // Publish offer to MQTT topic
                let offer = WebRTCOffer(sdp: sdp, type: "offer", from: state.userId, to: to)
                return .run { send in
                    await send(._internal(.setLoading(.sendingOffer, true)))
                    do {
                        let payload = try JSONEncoder().encode(offer)
                        let info = MQTTPublishInfo(
                            qos: .atLeastOnce, retain: false, topicName: to,
                            payload: ByteBuffer(data: payload), properties: .init([]))
                        try await mqttClientKit.publish(info)
                    } catch {
                        await send(._internal(.errorOccurred(error.localizedDescription)))
                    }
                    await send(._internal(.setLoading(.sendingOffer, false)))
                }

            case .view(.sendAnswer(let to, let sdp)):
                logger.info("🟠 [WebRTC] Sending answer to: \(to), sdp length: \(sdp.count)")
                let answer = WebRTCAnswer(sdp: sdp, type: "answer", from: state.userId, to: to)
                return .run { send in
                    await send(._internal(.setLoading(.sendingAnswer, true)))
                    do {
                        let payload = try JSONEncoder().encode(answer)
                        let info = MQTTPublishInfo(
                            qos: .atLeastOnce, retain: false, topicName: to,
                            payload: ByteBuffer(data: payload), properties: .init([]))
                        try await mqttClientKit.publish(info)
                    } catch {
                        await send(._internal(.errorOccurred(error.localizedDescription)))
                    }
                    await send(._internal(.setLoading(.sendingAnswer, false)))
                }

            case .view(.sendIceCandidate(let to, let candidate, let sdpMLineIndex, let sdpMid)):
                logger.info(
                    "🟠 [WebRTC] Sending ICE candidate to: \(to), candidate: \(candidate.prefix(20))..."
                )
                let iceCandidate = ICECandidate(
                    candidate: candidate, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid,
                    from: state.userId, to: to)
                return .run { send in
                    await send(._internal(.setLoading(.sendingIceCandidate, true)))
                    do {
                        let payload = try JSONEncoder().encode(iceCandidate)
                        let info = MQTTPublishInfo(
                            qos: .atLeastOnce, retain: false, topicName: to,
                            payload: ByteBuffer(data: payload), properties: .init([]))
                        try await mqttClientKit.publish(info)
                    } catch {
                        await send(._internal(.errorOccurred(error.localizedDescription)))
                    }
                    await send(._internal(.setLoading(.sendingIceCandidate, false)))
                }

            case .view(.clearMessages):
                state.messages = []
                return .none

            case .view(.clearError):
                state.lastError = nil
                return .none

            // WebRTC View Actions
            case .view(.createOfferForUser(let userId)):
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

            case ._internal(.setLoading(let item, let isLoading)):
                if isLoading {
                    state.loadingItems.insert(item)
                } else {
                    state.loadingItems.remove(item)
                }
                return .none

            case ._internal(.connectionStatusChanged(let status)):
                state.connectionStatus = status
                return .none

            case ._internal(.mqttMessageReceived(let message)):
                logger.info(
                    "🟠 [MQTT] Message received: topic=\(message.topicName), payload=\(message.payload.readableBytes) bytes"
                )
                state.messages.append(message)
                if state.messages.count > 50 {
                    state.messages.removeFirst()
                }
                // TODO: Parse message and handle offers/answers/ICE
                return .none

            case ._internal(.offerReceived(let offer)):
                logger.info(
                    "🟠 [WebRTC] Offer received: from=\(offer.from), to=\(offer.to), sdp length=\(offer.sdp.count)"
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

            case ._internal(.answerReceived(let answer)):
                logger.info(
                    "🟠 [WebRTC] Answer received: from=\(answer.from), to=\(answer.to), sdp length=\(answer.sdp.count)"
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

            case ._internal(.iceCandidateReceived(let candidate)):
                logger.info(
                    "🟠 [WebRTC] ICE candidate received: from=\(candidate.from), to=\(candidate.to), candidate=\(candidate.candidate.prefix(20))..."
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

            case ._internal(.roomUpdateReceived(let roomInfo)):
                logger.info("🟠 [MQTT] Room update received: users=\(roomInfo.users)")
                state.connectedUsers = roomInfo.users
                return .none

            case ._internal(.errorOccurred(let error)):
                logger.error("🔴 [WebRTCMqttFeature] Error occurred: \(error)")
                state.lastError = error
                return .send(.delegate(.connectionError(error)))

            case ._internal(.mqttConnected):
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

            case ._internal(.mqttDisconnected):
                logger.info("🟠 [MQTT] MQTT Disconnected")
                state.connectionStatus = .disconnected(.noConnection)
                state.isJoinedToRoom = false
                state.connectedUsers = []
                return .none

            case ._internal(.roomJoined):
                logger.info("🟢 [MQTT] Room joined")
                state.isJoinedToRoom = true
                return .none

            case ._internal(.roomLeft):
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
            case ._internal(.webRTCOfferGenerated(let offer)):
                return .run { send in
                    do {
                        let payload = try JSONEncoder().encode(offer)
                        let info = MQTTPublishInfo(
                            qos: .atLeastOnce, retain: false, topicName: offer.to,
                            payload: ByteBuffer(data: payload), properties: .init([]))
                        try await mqttClientKit.publish(info)
                    } catch {
                        await send(
                            ._internal(
                                .errorOccurred(
                                    "Failed to send offer: \(error.localizedDescription)")))
                    }
                }

            case ._internal(.webRTCAnswerGenerated(let answer)):
                return .run { send in
                    do {
                        let payload = try JSONEncoder().encode(answer)
                        let info = MQTTPublishInfo(
                            qos: .atLeastOnce, retain: false, topicName: answer.to,
                            payload: ByteBuffer(data: payload), properties: .init([]))
                        try await mqttClientKit.publish(info)
                    } catch {
                        await send(
                            ._internal(
                                .errorOccurred(
                                    "Failed to send answer: \(error.localizedDescription)")))
                    }
                }

            case ._internal(.webRTCIceCandidateGenerated(let candidate)):
                return .run { send in
                    do {
                        let payload = try JSONEncoder().encode(candidate)
                        let info = MQTTPublishInfo(
                            qos: .atLeastOnce, retain: false, topicName: candidate.to,
                            payload: ByteBuffer(data: payload), properties: .init([]))
                        try await mqttClientKit.publish(info)
                    } catch {
                        await send(
                            ._internal(
                                .errorOccurred(
                                    "Failed to send ICE candidate: \(error.localizedDescription)")))
                    }
                }

            case ._internal(.peerConnectionCreated(let userId)):
                return .none

            case ._internal(.peerConnectionRemoved(let userId)):
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

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    // MARK: - Helper Functions

    private func executeDisconnect(state: inout State) -> Effect<Action> {
        let roomId = state.roomId
        let connectedUsers = state.connectedUsers
        let isJoinedToRoom = state.isJoinedToRoom
        return .run { send in
            do {
                if isJoinedToRoom {
                    await send(._internal(.setLoading(.leavingRoom, true)))
                    try await mqttClientKit.unsubscribe(roomId)
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
