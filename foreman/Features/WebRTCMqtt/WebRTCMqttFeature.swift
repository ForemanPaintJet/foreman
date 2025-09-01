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
        var mqttFeature: MqttFeature.State = MqttFeature.State(
            connectionInfo: MqttClientKitInfo(
                address: "192.168.1.103",
                port: 1883,
                clientID: ""
            )
        )

        var userId: String = ""
        var connectedUsers: [String] = []
        var lastError: String?
        var isJoinedToRoom: Bool = false

        // MQTT-specific WebRTC message handling
        var pendingOffers: [WebRTCOffer] = []
        var pendingAnswers: [WebRTCAnswer] = []
        var pendingIceCandidates: [ICECandidate] = []
        
        var directVideoCall: DirectVideoCallFeature.State = DirectVideoCallFeature.State()
        var webRTCFeature: WebRTCFeature.State = WebRTCFeature.State()
        var deviceStats: DeviceStatsFeature.State = DeviceStatsFeature.State()
        var ifstat: IfstatFeature.State = IfstatFeature.State()
        var logoRotationAngle: Double = 90.0
        var showDeviceStats: Bool = false
        var showIfstat: Bool = false

        @Presents var alert: AlertState<Action.Alert>?
        
        // Computed properties for easier View access
        var connectionStatus: MqttClientKit.State {
            mqttFeature.connectionState
        }
        
        var mqttInfo: MqttClientKitInfo {
            get { mqttFeature.connectionInfo }
            set { mqttFeature.connectionInfo = newValue }
        }

        mutating func generateDefaultUserId() {
            userId = "user_\(UUID().uuidString.prefix(8))"
            mqttFeature.connectionInfo.clientID = userId
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
        case deviceStats(DeviceStatsFeature.Action)
        case ifstat(IfstatFeature.Action)
        case mqttFeature(MqttFeature.Action)

        @CasePathable
        enum ViewAction: Equatable {
            case task
            case teardown
            case connectToBroker
            case disconnect
            case joinRoom
            case leaveRoom
            case clearError
            case resetLogoRotation
            case showDeviceStats(Bool)
            case showIfstat(Bool)
        }

        @CasePathable
        enum InternalAction: Equatable {
            case setLoading(State.LoadingItem, Bool)
            case offerReceived(WebRTCOffer)
            case iceCandidateReceived(ICECandidate)
            case errorOccurred(String)
            case roomJoined
            case roomLeft
            case setLogoRotation(Double)

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
        Scope(state: \.deviceStats, action: \.deviceStats) {
            DeviceStatsFeature()
        }
        Scope(state: \.ifstat, action: \.ifstat) {
            IfstatFeature()
        }
        Scope(state: \.mqttFeature, action: \.mqttFeature) {
            MqttFeature()
        }
        Reduce(core)
            .ifLet(\.$alert, action: \.alert)
    }

    func core(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .binding(\.userId):
            state.mqttFeature.connectionInfo.clientID = state.userId
            return .none
        case .binding(\.mqttInfo):
            // mqttInfo binding is handled automatically through the computed property
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
            
        case .deviceStats:
            return .none
            
        case .ifstat:
            return .none
            
        case .mqttFeature(.delegate(let delegateAction)):
            return handleMqttFeatureDelegate(into: &state, action: delegateAction)
            
        case .mqttFeature:
            return .none

        case .alert(.presented(.confirmDisconnect)):
            return .send(.mqttFeature(.view(.disconnectButtonTapped)))

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
                !state.mqttFeature.connectionInfo.address.isEmpty,
                !state.userId.isEmpty
            else {
                return .send(
                    ._internal(
                        .errorOccurred("MQTT address, Room ID, and User ID are required")))
            }
            
            let address = state.mqttFeature.connectionInfo.address
            let port = state.mqttFeature.connectionInfo.port
            let clientId = state.mqttFeature.connectionInfo.clientID
            
            logger.info(
                "🟠 [MQTT] Connecting to broker: address=\(address), port=\(port), clientID=\(clientId)"
            )
            
            return .send(.mqttFeature(.view(.connectButtonTapped)))
        case .disconnect:
            return .send(.mqttFeature(.view(.disconnectButtonTapped)))
            
        case .joinRoom:
            guard !state.userId.isEmpty else {
                return .send(._internal(.errorOccurred("Room ID and User ID are required")))
            }
            guard state.mqttFeature.connectionState == .connected else {
                return .send(._internal(.errorOccurred("Not connected to MQTT broker")))
            }
            let userId = state.userId
            logger.info("🟠 [MQTT] userId=\(userId)")
            
            return .run { send in
                await send(._internal(.setLoading(.joiningRoom, true)))
                
                // Subscribe to output topic using new API
                await send(.mqttFeature(.subscriber(.view(.subscribe(MQTTSubscribeInfo(topicFilter: outputTopic, qos: .exactlyOnce))))))
                
                // Publish request video message
                let msg = RequestVideoMessage(clientId: userId, videoSource: "")
                do {
                    let payload = try JSONEncoder().encode(msg)
                    let payloadString = String(data: payload, encoding: .utf8) ?? ""
                    await send(.mqttFeature(.publisher(.publishWithDetails(
                        topic: inputTopic,
                        payload: payloadString,
                        qos: .exactlyOnce,
                        retain: false
                    ))))
                    
                    await send(._internal(.roomJoined))
                    await send(.delegate(.didJoinRoom("")))
                } catch {
                    await send(._internal(.errorOccurred(error.localizedDescription)))
                }
                await send(._internal(.setLoading(.joiningRoom, false)))
            }
            
        case .leaveRoom:
            let userId = state.userId
            
            guard state.isJoinedToRoom else { return .none }
            return .run { send in
                await send(._internal(.setLoading(.leavingRoom, true)))
                do {
                    // Unsubscribe from output topic
                    // Note: We would need to find the specific subscription and remove it
                    // For now, we'll send leave message and mark room as left
                    
                    let msg = LeaveVideoMessage(clientId: userId, videoSource: "")
                    let payload = try JSONEncoder().encode(msg)
                    let payloadString = String(data: payload, encoding: .utf8) ?? ""
                    await send(.mqttFeature(.publisher(.publishWithDetails(
                        topic: inputTopic,
                        payload: payloadString,
                        qos: .atLeastOnce,
                        retain: false
                    ))))
                    
                    await send(._internal(.roomLeft))
                    await send(.delegate(.didLeaveRoom))
                } catch {
                    await send(._internal(.errorOccurred(error.localizedDescription)))
                }
                await send(._internal(.setLoading(.leavingRoom, false)))
            }
            
            
        case .clearError:
            state.lastError = nil
            return .none
            
        case .resetLogoRotation:
            return .run { send in
                await send(._internal(.setLogoRotation(0)), animation: .bouncy(duration: 1.0))
            }
            
        case .showDeviceStats(let show):
            state.showDeviceStats = show
            return .none
            
        case .showIfstat(let show):
            state.showIfstat = show
            return .none
        }
    }

    private func handleInternalAction(into state: inout State, action: Action.InternalAction)
        -> Effect<Action>
    {
        switch action {
        case .setLoading(let item, let isLoading):
            if isLoading {
                state.loadingItems.insert(item)
            } else {
                state.loadingItems.remove(item)
            }
            return .none

        // MQTT message parsing is now handled by MqttFeature delegate

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
                    let payloadString = String(data: payload, encoding: .utf8) ?? ""
                    await send(.mqttFeature(.publisher(.publishWithDetails(
                        topic: inputTopic,
                        payload: payloadString,
                        qos: .atLeastOnce,
                        retain: false
                    ))))
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
                    let payloadString = String(data: payload, encoding: .utf8) ?? ""
                    await send(.mqttFeature(.publisher(.publishWithDetails(
                        topic: inputTopic,
                        payload: payloadString,
                        qos: .atLeastOnce,
                        retain: false
                    ))))
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
                    let payloadString = String(data: payload, encoding: .utf8) ?? ""
                    await send(.mqttFeature(.publisher(.publishWithDetails(
                        topic: inputTopic,
                        payload: payloadString,
                        qos: .atLeastOnce,
                        retain: false
                    ))))
                } catch {
                    await send(
                        ._internal(
                            .errorOccurred(
                                "Failed to send ICE candidate: \(error.localizedDescription)")))
                }
            }
            
        case .setLogoRotation(let angle):
            state.logoRotationAngle = angle
            return .none

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
            
        case let .errorOccurred(error, _):
            return .send(._internal(.errorOccurred("WebRTC Error: \(error.localizedDescription)")))
        }
    }
    

    // MARK: - MQTT Feature Delegate Handling
    
    private func handleMqttFeatureDelegate(into state: inout State, action: MqttFeature.Action.Delegate) -> Effect<Action> {
        switch action {
        case .connectionStatusChanged(let connectionState):
            logger.info("🟠 [MQTT] Connection status changed: \(String(describing: connectionState))")
            switch connectionState {
            case .connected:
                logger.info("🜢 [MQTT] MQTT Connected")
                state.lastError = nil
                return .send(.delegate(.didConnect))
            case .disconnected:
                logger.info("🟠 [MQTT] MQTT Disconnected")
                state.isJoinedToRoom = false
                state.connectedUsers = []
                return .send(.delegate(.didDisconnect))
            default:
                return .none
            }
            
        case .messageReceived(let message):
            logger.info("🟠 [MQTT] Message received: topic=\(message.topicName)")
            return handleReceivedMqttMessage(message, userId: state.userId)
            
        case .messagePublished(let message):
            logger.info("🜢 [MQTT] Message published successfully: topic=\(message.topicName)")
            return .none
            
        case .subscriptionAdded(let subscriptionInfo):
            logger.info("🜢 [MQTT] Subscribed to topic: \(subscriptionInfo.topicFilter)")
            return .none
            
        case .subscriptionRemoved(let topic):
            logger.info("🟠 [MQTT] Unsubscribed from topic: \(topic)")
            return .none
            
        case .errorOccurred(let error):
            logger.error("🔴 [MQTT] Error occurred: \(error)")
            state.lastError = error.localizedDescription
            return .send(.delegate(.connectionError(error.localizedDescription)))
        }
    }
    
    private func handleReceivedMqttMessage(_ message: MQTTPublishInfo, userId: String) -> Effect<Action> {
        guard message.topicName == outputTopic else {
            return .none
        }
        
        guard let data = message.payload.getData(at: 0, length: message.payload.readableBytes) else {
            return .none
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let json = json, 
                  let type = json["type"] as? String,
                  let clientId = json["clientId"] as? String,
                  clientId != userId else {
                return .none
            }
            
            switch type {
            case "offer":
                if let sdp = json["sdp"] as? String {
                    let offer = WebRTCOffer(
                        sdp: sdp, type: type, from: clientId, to: userId, videoSource: "")
                    logger.info("🟠 [MQTT] Parsed offer message")
                    return .send(._internal(.offerReceived(offer)))
                }
            case "ice":
                if let candidateObj = json["candidate"] as? [String: Any],
                   let candidate = candidateObj["candidate"] as? String,
                   let sdpMLineIndex = candidateObj["sdpMLineIndex"] as? Int {
                    let sdpMid: String? = candidateObj["sdpMid"] as? String
                    let ice = ICECandidate(
                        type: type, from: clientId, to: userId,
                        candidate: .init(
                            candidate: candidate, sdpMLineIndex: sdpMLineIndex,
                            sdpMid: sdpMid))
                    logger.info("🟠 [MQTT] Parsed ICE message")
                    return .send(._internal(.iceCandidateReceived(ice)))
                }
            case "requestVideo":
                logger.info("🟠 [MQTT] Received requestVideo message from clientId=\(clientId)")
                return .none
            case "leaveVideo":
                logger.info("🟠 [MQTT] Received leaveVideo message from clientId=\(clientId)")
                return .none
            default:
                logger.info("🟠 [MQTT] Unrecognized type: \(type)")
                return .none
            }
        } catch {
            logger.error("🔴 [MQTT] Failed to parse MQTT message payload: \(error)")
        }
        
        return .none
    }
}
