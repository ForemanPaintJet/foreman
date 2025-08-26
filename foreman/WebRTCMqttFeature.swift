//
//  WebRTCMqttFeature.swift
//  foreman
//
//  Created by Jed Lu on 2025/7/18.
//

import Combine
import ComposableArchitecture
import Foundation
import MQTTNIO
import MqttClientKit
import NIOCore
import OSLog
import SwiftUI
import WebRTCCore

// MARK: - Video Request Models

struct RequestVideoMessage: Codable, Equatable {
    var type: String = "requestVideo"
    let clientId: String
    let videoSource: String
    // Optional: resolution, format, etc.
    // let resolution: String?
    // let format: String?
}

struct LeaveVideoMessage: Codable, Equatable {
    var type: String = "leaveVideo"
    let clientId: String
    let videoSource: String
}

// MARK: - MQTT JSON Models (Legacy Format for Server Compatibility)

/// MQTT-specific WebRTC Offer model that maintains clientId for server compatibility
struct MqttWebRTCOffer: Codable, Equatable {
    let sdp: String
    let type: String
    let clientId: String  // Legacy format for server compatibility
    let videoSource: String
    
    init(from webRTCOffer: WebRTCOffer) {
        self.sdp = webRTCOffer.sdp
        self.type = webRTCOffer.type
        self.clientId = webRTCOffer.from  // Convert from -> clientId for outgoing messages
        self.videoSource = webRTCOffer.videoSource
    }
}

/// MQTT-specific WebRTC Answer model that maintains clientId for server compatibility
struct MqttWebRTCAnswer: Codable, Equatable {
    let sdp: String
    let type: String
    let clientId: String  // Legacy format for server compatibility
    let videoSource: String
    
    init(from webRTCAnswer: WebRTCAnswer) {
        self.sdp = webRTCAnswer.sdp
        self.type = webRTCAnswer.type
        self.clientId = webRTCAnswer.from  // Convert from -> clientId for outgoing messages
        self.videoSource = webRTCAnswer.videoSource
    }
}

/// MQTT-specific ICE Candidate model that maintains clientId for server compatibility
struct MqttICECandidate: Codable, Equatable {
    struct Candidate: Codable, Equatable {
        let candidate: String
        let sdpMLineIndex: Int
        let sdpMid: String?
    }
    
    let type: String
    let clientId: String  // Legacy format for server compatibility
    let candidate: Candidate
    
    init(from iceCandidate: ICECandidate) {
        self.type = iceCandidate.type
        self.clientId = iceCandidate.from  // Convert from -> clientId for outgoing messages
        self.candidate = Candidate(
            candidate: iceCandidate.candidate.candidate,
            sdpMLineIndex: iceCandidate.candidate.sdpMLineIndex,
            sdpMid: iceCandidate.candidate.sdpMid
        )
    }
}


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
        }

        var loadingItems: Set<LoadingItem> = []
        var connectionStatus: MqttClientKit.State = .idle
        var mqttInfo: MqttClientKitInfo = .init(
            address: "192.168.1.103", port: 1883, clientID: "")

        var userId: String = ""
        var connectedUsers: [String] = []
        var lastError: String?
        var messages: [MQTTPublishInfo] = []
        var isJoinedToRoom: Bool = false

        // MQTT-specific WebRTC message handling
        var pendingOffers: [WebRTCOffer] = []
        var pendingAnswers: [WebRTCAnswer] = []
        var pendingIceCandidates: [ICECandidate] = []
        
        var directVideoCall: DirectVideoCallFeature.State = DirectVideoCallFeature.State()
        var webRTCFeature: WebRTCFeature.State = WebRTCFeature.State()

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
        case directVideoCall(DirectVideoCallFeature.Action)
        case webRTCFeature(WebRTCFeature.Action)

        @CasePathable
        enum ViewAction: Equatable {
            case task
            case teardown
            case connectToBroker
            case disconnect
            case joinRoom
            case leaveRoom
            case clearMessages
            case clearError
        }

        @CasePathable
        enum InternalAction: Equatable {
            case setLoading(State.LoadingItem, Bool)
            case connectionStatusChanged(MqttClientKit.State)
            case mqttMessageReceived(MQTTPublishInfo)
            case offerReceived(WebRTCOffer)
            case iceCandidateReceived(ICECandidate)
            case errorOccurred(String)
            case mqttConnected
            case mqttDisconnected
            case roomJoined
            case roomLeft

            // WebRTC MQTT publishing actions
            case webRTCOfferGenerated(WebRTCOffer)
            case webRTCAnswerGenerated(WebRTCAnswer)
            case webRTCIceCandidateGenerated(ICECandidate)
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
        Scope(state: \.directVideoCall, action: \.directVideoCall) {
            DirectVideoCallFeature()
        }
        Scope(state: \.webRTCFeature, action: \.webRTCFeature) {
            WebRTCFeature()
        }
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
            
        case .directVideoCall:
            return .none
            
        case .webRTCFeature(.delegate(let delegateAction)):
            return handleWebRTCFeatureDelegate(into: &state, action: delegateAction)
            
        case .webRTCFeature:
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

        switch action {
        case .task:
            logger.info(
                "🟠 [WebRTCMqttFeature] task: Generating default userId and starting WebRTC feature")
            state.generateDefaultUserId()
            // Start the WebRTCFeature which will handle WebRTC events through its delegate
            return .send(.webRTCFeature(.view(.task)))

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
                    let msg = LeaveVideoMessage(clientId: state.userId, videoSource: "")
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


        case .clearMessages:
            state.messages = []
            return .none

        case .clearError:
            state.lastError = nil
            return .none
        }
    }

    private func handleInternalAction(into state: inout State, action: Action.InternalAction)
        -> Effect<Action>
    {
        @Dependency(\.mqttClientKit) var mqttClientKit

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
                                    sdp: sdp, type: type, from: clientId, to: state.userId, videoSource: "")
                                logger.info("🟠 [MQTT] Parsed offer message")
                                if clientId == state.userId {
                                    logger.info("Ignore message from self.")
                                    return .none
                                }
                                return .send(._internal(.offerReceived(offer)))
                            }
                        case "ice":
                            if let candidateObj = json["candidate"] as? [String: Any],
                                let candidate = candidateObj["candidate"] as? String,
                                let sdpMLineIndex = candidateObj["sdpMLineIndex"] as? Int
                            {
                                let sdpMid: String? = candidateObj["sdpMid"] as? String
                                let ice = ICECandidate(
                                    type: type, from: clientId, to: state.userId,
                                    candidate: .init(
                                        candidate: candidate, sdpMLineIndex: sdpMLineIndex,
                                        sdpMid: sdpMid))
                                logger.info("🟠 [MQTT] Parsed ICE message")
                                if clientId == state.userId {
                                    logger.info("Ignore message from self.")
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
                "🟠 [WebRTC] Offer received: from=\(offer.from), sdp length=\(offer.sdp.count)"
            )
            state.pendingOffers.append(offer)
            // Pass the offer directly to WebRTCFeature as it already has proper from/to format
            return .send(.webRTCFeature(.view(.handleRemoteOffer(offer))))

//        case .answerReceived(let answer):
//            logger.info(
//                "🟠 [WebRTC] Answer received: from=\(answer.clientId), sdp length=\(answer.sdp.count)"
//            )
//            state.pendingAnswers.append(answer)
//            // Use WebRTCCore models - directly pass the answer to WebRTCFeature
//            return .send(.webRTCFeature(.view(.handleRemoteOffer(<#T##WebRTCOffer#>, userId: <#T##String#>))))
//            return .send(.webRTCFeature(.view(.handleRemoteAnswer(answer, userId: answer.clientId))))

        case .iceCandidateReceived(let candidate):
            logger.info(
                "🟠 [WebRTC] ICE candidate received: from=\(candidate.from), candidate=\(candidate.candidate.candidate.prefix(20))..."
            )
            state.pendingIceCandidates.append(candidate)
            // Pass the candidate directly to WebRTCFeature as it already has proper from/to format
            return .send(.webRTCFeature(.view(.handleICECandidate(candidate))))

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
            state.connectedUsers = []
            // Use WebRTCFeature to remove all peer connections
            let connectedPeers = state.webRTCFeature.connectedPeers
//            let effects = connectedPeers.map { peer in
//                Effect<Action>.send(.webRTCFeature(.view(.removePeerConnection(userId: peer.id))))
//            }
            return .none

        // WebRTC Internal Actions
        case .webRTCOfferGenerated(let offer):
            return .run { send in
                do {
                    // Convert to MQTT-compatible format with clientId
                    let mqttOffer = MqttWebRTCOffer(from: offer)
                    let payload = try JSONEncoder().encode(mqttOffer)
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
                    // Convert to MQTT-compatible format with clientId
                    let mqttAnswer = MqttWebRTCAnswer(from: answer)
                    let payload = try JSONEncoder().encode(mqttAnswer)
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
                    // Convert to MQTT-compatible format with clientId
                    let mqttCandidate = MqttICECandidate(from: candidate)
                    let payload = try JSONEncoder().encode(mqttCandidate)
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

        }
    }

    // MARK: - Helper Functions
    
    private func handleWebRTCFeatureDelegate(into state: inout State, action: WebRTCFeature.Delegate) -> Effect<Action> {
        switch action {
        case let .offerGenerated(sdp, userId):
            let offer = WebRTCOffer(sdp: sdp, type: "offer", from: state.userId, to: userId, videoSource: "")
            return .send(._internal(.webRTCOfferGenerated(offer)))
            
        case let .answerGenerated(sdp, userId):
            let answer = WebRTCAnswer(sdp: sdp, type: "answer", from: state.userId, to: userId, videoSource: "")
            return .send(._internal(.webRTCAnswerGenerated(answer)))
            
        case let .iceCandidateGenerated(candidate, sdpMLineIndex, sdpMid, userId):
            let iceCandidate = ICECandidate(
                type: "ice",
                from: state.userId,
                to: userId,
                candidate: .init(
                    candidate: candidate,
                    sdpMLineIndex: sdpMLineIndex,
                    sdpMid: sdpMid
                )
            )
            return .send(._internal(.webRTCIceCandidateGenerated(iceCandidate)))
            
        case let .videoTrackAdded(trackInfo):
            // Update DirectVideoCall feature with video track info
            state.directVideoCall.remoteVideoTracks.append(trackInfo)
            return .none
            
        case let .videoTrackRemoved(userId):
            // Update DirectVideoCall feature after video track removal
            state.directVideoCall.remoteVideoTracks = state.webRTCFeature.connectedPeers.compactMap { $0.videoTrack }
            return .none
            
        case let .connectionStateChanged(userId, connectionState):
            // Update DirectVideoCall feature with connection state changes
//            state.directVideoCall.remoteVideoTracks = state.webRTCFeature.connectedPeers.compactMap { $0.videoTrack }
            return .none
            
        case let .errorOccurred(error, userId):
            return .send(._internal(.errorOccurred("WebRTC Error: \(error.localizedDescription)")))
        }
    }
    

    private func executeDisconnect(state: inout State) -> Effect<Action> {
        let isJoinedToRoom = state.isJoinedToRoom

        @Dependency(\.mqttClientKit) var mqttClientKit

        return .run { send in
            do {
                if isJoinedToRoom {
                    await send(._internal(.setLoading(.leavingRoom, true)))
                    try await mqttClientKit.unsubscribe(outputTopic)
                    await send(._internal(.roomLeft))
                    await send(.delegate(.didLeaveRoom))
                    await send(._internal(.setLoading(.leavingRoom, false)))
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
