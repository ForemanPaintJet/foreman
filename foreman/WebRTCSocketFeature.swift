//
//  WebRTCSocketFeature.swift
//  foreman
//
//  Created by Jed Lu on 2025/7/3.
//

import Combine
import ComposableArchitecture
import Foundation
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
        var serverURL: String = "ws://localhost:8765"
        var roomId: String = ""
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

    enum Action: TCAFeatureAction {
        @CasePathable
        enum ViewAction: Equatable {
            case onAppear
            case onDisappear
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

    @Dependency(\.socketClient) var socketClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .view(.onAppear):
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
                    }
                }
                .cancellable(id: "SocketStreams")

            case .view(.onDisappear):
                return .cancel(id: "SocketStreams")

            case .view(.updateServerURL(let url)):
                state.serverURL = url
                return .none

            case .view(.updateRoomId(let roomId)):
                state.roomId = roomId
                return .none

            case .view(.updateUserId(let userId)):
                state.userId = userId
                return .none

            case .view(.connectToServer):
                guard !state.serverURL.isEmpty else {
                    return .send(._internal(.errorOccurred("Server URL is required")))
                }

                return .run { [serverURL = state.serverURL] send in
                    await send(._internal(.setLoading(.connecting, true)))

                    guard let url = URL(string: serverURL) else {
                        await send(._internal(.errorOccurred("Invalid server URL")))
                        await send(._internal(.setLoading(.connecting, false)))
                        return
                    }

                    do {
                        try await socketClient.connect(url)
                        await send(._internal(.socketConnected))
                        await send(.delegate(.didConnect))
                    } catch {
                        await send(._internal(.errorOccurred(error.localizedDescription)))
                    }

                    await send(._internal(.setLoading(.connecting, false)))
                }

            case .view(.disconnect):
                if state.isJoinedToRoom {
                    state.alert = AlertState {
                        TextState("Disconnect from Server")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("Cancel")
                        }
                        ButtonState(action: .confirmDisconnect) {
                            TextState("Disconnect")
                        }
                    } message: {
                        TextState(
                            "You are currently in a room. Disconnecting will leave the room. Continue?"
                        )
                    }
                    return .none
                } else {
                    return executeDisconnect(state: &state)
                }

            case .view(.joinRoom):
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

            case .view(.leaveRoom):
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

            case .view(.sendOffer(let to, let sdp)):
                let offer = WebRTCOffer(sdp: sdp, type: "offer", from: state.userId, to: to)

                return .run { send in
                    await send(._internal(.setLoading(.sendingOffer, true)))

                    do {
                        try await socketClient.sendOffer(offer)
                    } catch {
                        await send(._internal(.errorOccurred(error.localizedDescription)))
                    }

                    await send(._internal(.setLoading(.sendingOffer, false)))
                }

            case .view(.sendAnswer(let to, let sdp)):
                let answer = WebRTCAnswer(sdp: sdp, type: "answer", from: state.userId, to: to)

                return .run { send in
                    await send(._internal(.setLoading(.sendingAnswer, true)))

                    do {
                        try await socketClient.sendAnswer(answer)
                    } catch {
                        await send(._internal(.errorOccurred(error.localizedDescription)))
                    }

                    await send(._internal(.setLoading(.sendingAnswer, false)))
                }

            case .view(.sendIceCandidate(let to, let candidate, let sdpMLineIndex, let sdpMid)):
                let iceCandidate = ICECandidate(
                    candidate: candidate,
                    sdpMLineIndex: sdpMLineIndex,
                    sdpMid: sdpMid,
                    from: state.userId,
                    to: to
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

            case .view(.clearMessages):
                state.messages = []
                return .none

            case .view(.clearError):
                state.lastError = nil
                return .none

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

            case ._internal(.socketMessageReceived(let message)):
                state.messages.append(message)
                // Keep only last 50 messages
                if state.messages.count > 50 {
                    state.messages.removeFirst()
                }
                return .none

            case ._internal(.offerReceived(let offer)):
                state.pendingOffers.append(offer)
                return .send(.delegate(.didReceiveOffer(offer)))

            case ._internal(.answerReceived(let answer)):
                state.pendingAnswers.append(answer)
                return .send(.delegate(.didReceiveAnswer(answer)))

            case ._internal(.iceCandidateReceived(let candidate)):
                state.pendingIceCandidates.append(candidate)
                return .send(.delegate(.didReceiveIceCandidate(candidate)))

            case ._internal(.roomUpdateReceived(let roomInfo)):
                state.connectedUsers = roomInfo.users
                return .none

            case ._internal(.errorOccurred(let error)):
                state.lastError = error
                return .send(.delegate(.connectionError(error)))

            case ._internal(.socketConnected):
                state.connectionStatus = .connected
                state.lastError = nil
                return .none

            case ._internal(.socketDisconnected):
                state.connectionStatus = .disconnected
                state.isJoinedToRoom = false
                state.connectedUsers = []
                return .none

            case ._internal(.roomJoined):
                state.isJoinedToRoom = true
                return .none

            case ._internal(.roomLeft):
                state.isJoinedToRoom = false
                state.connectedUsers = []
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
        return .run { send in
            do {
                try await socketClient.disconnect()
                await send(._internal(.socketDisconnected))
                await send(.delegate(.didDisconnect))
            } catch {
                await send(._internal(.errorOccurred(error.localizedDescription)))
            }
        }
    }
}
