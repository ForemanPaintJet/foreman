//
//  WebRTCSocketFeature.swift
//  foreman
//
//  Created by Jed Lu on 2025/7/3.
//

import Combine
import ComposableArchitecture
import Foundation
import OSLog
import SwiftUI

// MARK: - WebRTC Socket Feature

@Reducer
struct WebRTCSocketFeature {
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
        var connectionStatus: ConnectionStatus = .disconnected
        var serverURL: String = "ws://192.168.1.112:8765"
        var roomId: String = "oak-room"
        var userId: String = ""
        var connectedUsers: [String] = []
        var lastError: String?
        var messages: [SocketMessage] = []
        var isJoinedToRoom: Bool = false

        // WebRTC specific state
        var pendingOffers: [WebRTCOffer] = []
        var pendingAnswers: [WebRTCAnswer] = []
        var pendingIceCandidates: [ICECandidate] = []

        @Presents var alert: AlertState<Action.Alert>?

        mutating func generateDefaultUserId() {
            userId = "user_\(UUID().uuidString.prefix(8))"
        }
    }

    @CasePathable
    enum Action: Equatable, BindableAction {
        case view(ViewAction)
        case binding(BindingAction<State>)
        case _internal(InternalAction)
        case delegate(DelegateAction)
        case alert(PresentationAction<Alert>)

        @CasePathable
        enum ViewAction: Equatable {
            case task
            case teardown
            case updateServerURL(String)
            case updateRoomId(String)
            case updateUserId(String)
            case connectToServer
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
            case connectionStatusChanged(ConnectionStatus)
            case socketMessageReceived(SocketMessage)
            case offerReceived(WebRTCOffer)
            case answerReceived(WebRTCAnswer)
            case iceCandidateReceived(ICECandidate)
            case roomUpdateReceived(RoomInfo)
            case errorOccurred(String)
            case socketConnected
            case socketDisconnected
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

    private let logger = Logger(subsystem: "foreman", category: "WebRTCSocketFeature")

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce(core)
            .ifLet(\.$alert, action: \.alert)
    }

    func core(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .binding:
            return .none

        case let .view(viewAction):
            return handleViewAction(into: &state, action: viewAction)

        case let ._internal(internalAction):
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
        @Dependency(\.socketClient) var socketClient
        @Dependency(\.webRTCClient) var webRTCClient

        switch action {
        case .task:
            state.generateDefaultUserId()
            return .run { send in
                // Subscribe to socket streams
                await withTaskGroup(of: Void.self) { group in
                    // Connection status stream
                    group.addTask {
                        for await status in await socketClient.connectionStatusStream() {
                            await send(._internal(.connectionStatusChanged(status)))
                        }
                    }

                    // Message stream
                    group.addTask {
                        for await message in await socketClient.messageStream() {
                            await send(._internal(.socketMessageReceived(message)))
                        }
                    }

                    // Offer stream
                    group.addTask {
                        for await offer in await socketClient.offerStream() {
                            await send(._internal(.offerReceived(offer)))
                        }
                    }

                    // Answer stream
                    group.addTask {
                        for await answer in await socketClient.answerStream() {
                            await send(._internal(.answerReceived(answer)))
                        }
                    }

                    // ICE candidate stream
                    group.addTask {
                        for await candidate in await socketClient.iceCandidateStream() {
                            await send(._internal(.iceCandidateReceived(candidate)))
                        }
                    }

                    // Room update stream
                    group.addTask {
                        for await roomInfo in await socketClient.roomUpdateStream() {
                            await send(._internal(.roomUpdateReceived(roomInfo)))
                        }
                    }

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
            .cancellable(id: "SocketStreams")

        case .teardown:
            return .cancel(id: "SocketStreams")

        case .updateServerURL(let url):
            state.serverURL = url
            return .none

        case .updateRoomId(let roomId):
            state.roomId = roomId
            return .none

        case .updateUserId(let userId):
            state.userId = userId
            return .none

        case .connectToServer:
            guard !state.serverURL.isEmpty && !state.roomId.isEmpty && !state.userId.isEmpty else {
                return .send(
                    ._internal(.errorOccurred("Server URL, Room ID, and User ID are required")))
            }

            return .run { [serverURL = state.serverURL] send in
                await send(._internal(.setLoading(.connecting, true)))

                guard let url = URL(string: serverURL) else {
                    await send(._internal(.errorOccurred("Invalid server URL")))
                    await send(._internal(.setLoading(.connecting, false)))
                    return
                }

                do {
                    // Connect to server - this will start the WebSocket connection
                    // We'll wait for the server's 'connected' event before joining the room
                    try await socketClient.connect(url)
                    await send(._internal(.socketConnected))
                    await send(.delegate(.didConnect))
                } catch {
                    await send(
                        ._internal(
                            .errorOccurred("Failed to connect: \(error.localizedDescription)")))
                    await send(._internal(.setLoading(.connecting, false)))
                }
            }

        case .disconnect:
            return executeDisconnect(state: &state)

        case .joinRoom:
            guard !state.roomId.isEmpty && !state.userId.isEmpty else {
                return .send(._internal(.errorOccurred("Room ID and User ID are required")))
            }

            guard state.connectionStatus == .connected else {
                return .send(._internal(.errorOccurred("Not connected to server")))
            }

            return .run { [roomId = state.roomId, userId = state.userId] send in
                await send(._internal(.setLoading(.joiningRoom, true)))

                do {
                    try await socketClient.joinRoom(roomId, userId)
                    await send(._internal(.roomJoined))
                    await send(.delegate(.didJoinRoom(roomId)))
                } catch {
                    await send(._internal(.errorOccurred(error.localizedDescription)))
                }

                await send(._internal(.setLoading(.joiningRoom, false)))
            }

        case .leaveRoom:
            guard state.isJoinedToRoom else { return .none }

            return .run { [roomId = state.roomId] send in
                await send(._internal(.setLoading(.leavingRoom, true)))

                do {
                    try await socketClient.leaveRoom(roomId)
                    await send(._internal(.roomLeft))
                    await send(.delegate(.didLeaveRoom))
                } catch {
                    await send(._internal(.errorOccurred(error.localizedDescription)))
                }

                await send(._internal(.setLoading(.leavingRoom, false)))
            }

        case .sendOffer(let to, let sdp):
            let offer = WebRTCOffer(
                sdp: sdp, type: "offer", clientId: state.userId, videoSource: "")

            return .run { send in
                await send(._internal(.setLoading(.sendingOffer, true)))

                do {
                    try await socketClient.sendOffer(offer)
                } catch {
                    await send(._internal(.errorOccurred(error.localizedDescription)))
                }

                await send(._internal(.setLoading(.sendingOffer, false)))
            }

        case .sendAnswer(let to, let sdp):
            let answer = WebRTCAnswer(
                sdp: sdp, type: "answer", clientId: state.userId, videoSource: "")

            return .run { send in
                await send(._internal(.setLoading(.sendingAnswer, true)))

                do {
                    try await socketClient.sendAnswer(answer)
                } catch {
                    await send(._internal(.errorOccurred(error.localizedDescription)))
                }

                await send(._internal(.setLoading(.sendingAnswer, false)))
            }

        case .sendIceCandidate(let to, let candidate, let sdpMLineIndex, let sdpMid):
            let iceCandidate = ICECandidate(
                type: "ice", clientId: state.userId,
                candidate: .init(candidate: candidate, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
            )

            return .run { send in
                await send(._internal(.setLoading(.sendingIceCandidate, true)))

                do {
                    try await socketClient.sendIceCandidate(iceCandidate)
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
                    // Create peer connection if it doesn't exist
                    let created = await webRTCClient.createPeerConnection(userId)
                    if created {
                        await send(._internal(.peerConnectionCreated(userId)))
                    }

                    // Create offer
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
        @Dependency(\.socketClient) var socketClient
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

        case .socketMessageReceived(let message):
            logger.info("📨 TCA: Socket message received - type: \(message.type)")
            if let data = message.data {
                logger.info("📨 TCA: Message data keys: \(data.keys.sorted())")
            }

            // Handle special server events
            if message.type == "connected" {
                logger.info("🔗 TCA: Server confirmed connection, auto-joining room")
                if let data = message.data, let serverUserId = data["user_id"] as? String {
                    logger.info("🔗 TCA: Server assigned user ID: \(serverUserId)")
                    // Optionally update our user ID if the server assigned one
                }

                // Auto-join room now that server connection is confirmed
                return .run { [roomId = state.roomId, userId = state.userId] send in
                    await send(._internal(.setLoading(.connecting, false)))
                    await send(._internal(.setLoading(.joiningRoom, true)))

                    do {
                        try await socketClient.joinRoom(roomId, userId)
                        await send(._internal(.roomJoined))
                        await send(.delegate(.didJoinRoom(roomId)))
                    } catch {
                        await send(
                            ._internal(
                                .errorOccurred("Failed to join room: \(error.localizedDescription)")
                            ))
                    }

                    await send(._internal(.setLoading(.joiningRoom, false)))
                }
            }

            state.messages.append(message)
            // Keep only last 50 messages
            if state.messages.count > 50 {
                state.messages.removeFirst()
            }
            return .none

        case .offerReceived(let offer):
            logger.info("🔥 TCA: Offer received from \(offer.clientId)")
            logger.info("🔥 TCA: Offer SDP length: \(offer.sdp.count)")
            state.pendingOffers.append(offer)

            // Handle the incoming offer with WebRTC
            return .run { send in
                do {
                    logger.info("🔥 TCA: About to handle remote offer with WebRTC client")
                    try await webRTCClient.handleRemoteOffer(offer)
                    logger.info("🔥 TCA: Successfully handled remote offer")
                } catch {
                    logger.error("🔥 TCA: Failed to handle remote offer: \(error)")
                    await send(
                        ._internal(
                            .errorOccurred(
                                "Failed to handle remote offer: \(error.localizedDescription)"))
                    )
                }
            }

        case .answerReceived(let answer):
            state.pendingAnswers.append(answer)

            // Handle the incoming answer with WebRTC
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
            state.pendingIceCandidates.append(candidate)

            // Handle the incoming ICE candidate with WebRTC
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
            state.connectedUsers = roomInfo.users
            return .none

        case .errorOccurred(let error):
            state.lastError = error
            return .send(.delegate(.connectionError(error)))

        case .socketConnected:
            state.connectionStatus = .connected
            state.lastError = nil
            return .none

        case .socketDisconnected:
            state.connectionStatus = .disconnected
            state.isJoinedToRoom = false
            state.connectedUsers = []
            return .none

        case .roomJoined:
            state.isJoinedToRoom = true
            return .none

        case .roomLeft:
            state.isJoinedToRoom = false
            state.connectedUsers = []

            // Remove all peer connections when leaving room
            return .run { [connectedUsers = state.connectedUsers] send in
                for userId in connectedUsers {
                    await webRTCClient.removePeerConnection(userId)
                    await send(._internal(.peerConnectionRemoved(userId)))
                }
            }

        // WebRTC Internal Actions
        case .webRTCOfferGenerated(let offer):
            return .run { send in
                do {
                    try await socketClient.sendOffer(offer)
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
                    try await socketClient.sendAnswer(answer)
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
                    try await socketClient.sendIceCandidate(candidate)
                } catch {
                    await send(
                        ._internal(
                            .errorOccurred(
                                "Failed to send ICE candidate: \(error.localizedDescription)")))
                }
            }

        case .peerConnectionCreated(let userId):
            logger.info("🤝 Peer connection created for \(userId)")
            return .none

        case .peerConnectionRemoved(let userId):
            logger.info("🗑️ Peer connection removed for \(userId)")
            return .none
        }
    }

    // MARK: - Helper Functions

    private func executeDisconnect(state: inout State) -> Effect<Action> {
        return .run {
            [
                isJoinedToRoom = state.isJoinedToRoom, roomId = state.roomId,
                connectedUsers = state.connectedUsers
            ] send in
            do {
                // Leave room first if joined
                if isJoinedToRoom {
                    await send(._internal(.setLoading(.leavingRoom, true)))
                    try await socketClient.leaveRoom(roomId)
                    await send(._internal(.roomLeft))
                    await send(.delegate(.didLeaveRoom))
                    await send(._internal(.setLoading(.leavingRoom, false)))

                    // Remove all peer connections when leaving room
                    for userId in connectedUsers {
                        await webRTCClient.removePeerConnection(userId)
                        await send(._internal(.peerConnectionRemoved(userId)))
                    }
                }

                // Then disconnect from server
                try await socketClient.disconnect()
                await send(._internal(.socketDisconnected))
                await send(.delegate(.didDisconnect))
            } catch {
                await send(._internal(.errorOccurred(error.localizedDescription)))
            }
        }
    }
}
