//
//  WebRTCFeature.swift
//  WebRTCCore
//
//  Created by Claude on 2025/8/20.
//

import ComposableArchitecture
import Foundation
import OSLog
import WebRTC

// MARK: - WebRTC Feature

@Reducer
package struct WebRTCFeature {

    // MARK: - State

    @ObservableState
    package struct State: Equatable {
        package var connectedPeers: IdentifiedArrayOf<PeerState> = []
        package var localConnectionState: ConnectionState = .disconnected
        package var error: WebRTCError?
        package var isListening = false
    }

    // MARK: - Peer State

    @ObservableState
    package struct PeerState: Equatable, Identifiable {
        package let id: String
        package var videoTrack: VideoTrackInfo?
        package var connectionState: ConnectionState = .connecting

        package init(
            id: String, videoTrack: VideoTrackInfo? = nil,
            connectionState: ConnectionState = .connecting
        ) {
            self.id = id
            self.videoTrack = videoTrack
            self.connectionState = connectionState
        }
    }

    // MARK: - Connection State

    package enum ConnectionState: String, Equatable, CaseIterable {
        case disconnected
        case connecting
        case connected
        case failed
        case closed

        package var isConnected: Bool {
            self == .connected
        }
    }

    // MARK: - Actions

    @CasePathable
    package enum Action: Equatable, BindableAction, ComposableArchitecture.ViewAction {
        case view(ViewAction)
        case binding(BindingAction<State>)
        case delegate(Delegate)

        case startListening
        case stopListening
        case webRTCEvent(WebRTCEvent)
        case createPeerConnectionResult(String, Bool)
        case removePeerConnectionCompleted(String)
        case offerCreated(String)
        case remoteOfferHandled(String, RTCSessionDescription)
        case remoteAnswerSet(String)
        case iceCandidateAdded(String)
        case errorOccurred(WebRTCError, String?)
    }

    // MARK: - View Actions

    @CasePathable
    package enum ViewAction: Equatable {
        case task
        case createPeerConnection(userId: String)
        case removePeerConnection(userId: String)
        case createOffer(userId: String)
        case handleRemoteOffer(RTCSessionDescription, userId: String)
        case handleRemoteAnswer(RTCSessionDescription, userId: String)
        case handleICECandidate(RTCIceCandidate, userId: String)
        case dismissError
    }

    // MARK: - Delegate Actions

    @CasePathable
    package enum Delegate: Equatable {
        case offerGenerated(sdp: String, userId: String)
        case answerGenerated(sdp: String, userId: String)
        case iceCandidateGenerated(
            candidate: String, sdpMLineIndex: Int, sdpMid: String?, userId: String)
        case videoTrackAdded(VideoTrackInfo)
        case videoTrackRemoved(userId: String)
        case connectionStateChanged(userId: String, state: ConnectionState)
        case errorOccurred(WebRTCError, userId: String?)
    }

    // MARK: - Dependencies

    @Dependency(\.continuousClock) var clock
    private let logger = Logger(subsystem: "WebRTCCore", category: "WebRTCFeature")

    // MARK: - Reducer Body

    package var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce(core)
    }

    package func core(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .view(viewAction):
            return handleViewAction(viewAction, state: &state)

        case .startListening:
            state.isListening = true
            return .run { send in
                @Dependency(\.webRTCEngine) var webRTCEngine
                for await event in webRTCEngine.events() {
                    await send(.webRTCEvent(event))
                }
            }
            .cancellable(id: CancelID.webRTCEvents)

        case .stopListening:
            state.isListening = false
            return .cancel(id: CancelID.webRTCEvents)

        case let .webRTCEvent(event):
            return handleWebRTCEvent(event, state: &state)

        case let .createPeerConnectionResult(userId, success):
            if success {
                let peerState = PeerState(id: userId, connectionState: .connecting)
                state.connectedPeers.updateOrAppend(peerState)
            } else {
                return .send(.errorOccurred(.peerConnectionNotFound, userId))
            }
            return .none

        case let .removePeerConnectionCompleted(userId):
            state.connectedPeers.remove(id: userId)
            return .send(.delegate(.videoTrackRemoved(userId: userId)))

        case let .offerCreated(userId):
            logger.info("✅ WebRTCFeature: Offer created for \(userId)")
            return .none

        case let .remoteOfferHandled(userId, _):
            logger.info("✅ WebRTCFeature: Remote offer handled for \(userId)")
            return .none

        case let .remoteAnswerSet(userId):
            logger.info("✅ WebRTCFeature: Remote answer set for \(userId)")
            return .none

        case let .iceCandidateAdded(userId):
            logger.info("✅ WebRTCFeature: ICE candidate added for \(userId)")
            return .none

        case let .errorOccurred(error, userId):
            state.error = error
            logger.error(
                "❌ WebRTCFeature: Error occurred: \(error.localizedDescription), userId: \(userId ?? "nil")"
            )
            return .send(.delegate(.errorOccurred(error, userId: userId)))

        case .binding:
            return .none

        case .delegate:
            return .none
        }
    }

    // MARK: - Private Methods

    private func handleViewAction(_ viewAction: ViewAction, state: inout State) -> Effect<Action> {
        switch viewAction {
        case .task:
            guard !state.isListening else {
                return .none
            }
            return .send(.startListening)

        case let .createPeerConnection(userId):
            return .run { send in
                @Dependency(\.webRTCEngine) var webRTCEngine
                let success = await webRTCEngine.createPeerConnection(userId)
                await send(.createPeerConnectionResult(userId, success))
            }

        case let .removePeerConnection(userId):
            return .run { send in
                @Dependency(\.webRTCEngine) var webRTCEngine
                await webRTCEngine.removePeerConnection(userId)
                await send(.removePeerConnectionCompleted(userId))
            }

        case let .createOffer(userId):
            return .run { send in
                @Dependency(\.webRTCEngine) var webRTCEngine
                do {
                    try await webRTCEngine.createOffer(userId)
                    await send(.offerCreated(userId))
                } catch let error as WebRTCError {
                    await send(.errorOccurred(error, userId))
                } catch {
                    await send(.errorOccurred(.failedToCreateOffer, userId))
                }
            }

        case let .handleRemoteOffer(offer, userId):
            return .run { send in
                @Dependency(\.webRTCEngine) var webRTCEngine
                do {
                    let answer = try await webRTCEngine.setRemoteOffer(offer, userId)
                    await send(.remoteOfferHandled(userId, answer))
                } catch let error as WebRTCError {
                    await send(.errorOccurred(error, userId))
                } catch {
                    await send(.errorOccurred(.failedToSetDescription, userId))
                }
            }

        case let .handleRemoteAnswer(answer, userId):
            return .run { send in
                @Dependency(\.webRTCEngine) var webRTCEngine
                do {
                    try await webRTCEngine.setRemoteAnswer(answer, userId)
                    await send(.remoteAnswerSet(userId))
                } catch let error as WebRTCError {
                    await send(.errorOccurred(error, userId))
                } catch {
                    await send(.errorOccurred(.failedToSetDescription, userId))
                }
            }

        case let .handleICECandidate(candidate, userId):
            return .run { send in
                @Dependency(\.webRTCEngine) var webRTCEngine
                do {
                    try await webRTCEngine.addIceCandidate(candidate, userId)
                    await send(.iceCandidateAdded(userId))
                } catch let error as WebRTCError {
                    await send(.errorOccurred(error, userId))
                } catch {
                    await send(.errorOccurred(.failedToAddCandidate, userId))
                }
            }

        case .dismissError:
            state.error = nil
            return .none
        }
    }

    private func handleWebRTCEvent(_ event: WebRTCEvent, state: inout State) -> Effect<Action> {
        switch event {
        case let .offerGenerated(sdp, userId):
            return .send(.delegate(.offerGenerated(sdp: sdp, userId: userId)))

        case let .answerGenerated(sdp, userId):
            return .send(.delegate(.answerGenerated(sdp: sdp, userId: userId)))

        case let .iceCandidateGenerated(candidate, sdpMLineIndex, sdpMid, userId):
            return .send(
                .delegate(
                    .iceCandidateGenerated(
                        candidate: candidate,
                        sdpMLineIndex: sdpMLineIndex,
                        sdpMid: sdpMid,
                        userId: userId
                    )))

        case let .connectionStateChanged(stateString, userId):
            let connectionState =
                ConnectionState(rawValue: stateString.lowercased()) ?? .disconnected

            if var peer = state.connectedPeers[id: userId] {
                peer.connectionState = connectionState
                state.connectedPeers.updateOrAppend(peer)
            }

            return .send(.delegate(.connectionStateChanged(userId: userId, state: connectionState)))

        case let .iceConnectionStateChanged(stateString, userId):
            let connectionState =
                ConnectionState(rawValue: stateString.lowercased()) ?? .disconnected

            if var peer = state.connectedPeers[id: userId] {
                peer.connectionState = connectionState
                state.connectedPeers.updateOrAppend(peer)
            }

            return .send(.delegate(.connectionStateChanged(userId: userId, state: connectionState)))

        case let .videoTrackAdded(trackInfo):
            if var peer = state.connectedPeers[id: trackInfo.userId] {
                peer.videoTrack = trackInfo
                peer.connectionState = .connected
                state.connectedPeers.updateOrAppend(peer)
            } else {
                let peerState = PeerState(
                    id: trackInfo.userId,
                    videoTrack: trackInfo,
                    connectionState: .connected
                )
                state.connectedPeers.append(peerState)
            }

            return .send(.delegate(.videoTrackAdded(trackInfo)))

        case let .videoTrackRemoved(userId):
            if var peer = state.connectedPeers[id: userId] {
                peer.videoTrack = nil
                peer.connectionState = .disconnected
                state.connectedPeers.updateOrAppend(peer)
            }

            return .send(.delegate(.videoTrackRemoved(userId: userId)))

        case let .errorOccurred(error, userId):
            return .send(.errorOccurred(error, userId))
        }
    }

    // MARK: - Cancel IDs

    private enum CancelID: Hashable {
        case webRTCEvents
    }
}

// MARK: - Helpers

extension IdentifiedArrayOf where Element == WebRTCFeature.PeerState, ID == String {
    mutating func updateOrAppend(_ element: Element) {
        if self[id: element.id] != nil {
            self[id: element.id] = element
        } else {
            self.append(element)
        }
    }
}
