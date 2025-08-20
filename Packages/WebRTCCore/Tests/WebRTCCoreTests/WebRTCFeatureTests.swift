//
//  WebRTCFeatureTests.swift
//  WebRTCCore
//
//  Created by Claude on 2025/8/20.
//

import ComposableArchitecture
import CustomDump
import WebRTC
import XCTest

@testable import WebRTCCore

@MainActor
final class WebRTCFeatureTests: XCTestCase {

    func test_task_startsListening() async {
        let eventstream = AsyncStream.makeStream(of: WebRTCEvent.self)
        let store = TestStore(initialState: WebRTCFeature.State()) {
            WebRTCFeature()
        } withDependencies: {
            $0.webRTCEngine.events = { eventstream.stream }
        }
        
        await store.send(\.view, .task)
        await store.receive(\.startListening) {
            $0.isListening = true
        }
        
        eventstream.continuation.finish()
        
        await store.finish()
    }

    func test_createPeerConnection_success() async {
        let store = TestStore(initialState: WebRTCFeature.State()) {
            WebRTCFeature()
        } withDependencies: {
            $0.webRTCEngine.createPeerConnection = { _ in true }
        }

        await store.send(\.view, .createPeerConnection(userId: "user123"))
        await store.receive(.createPeerConnectionResult("user123", true)) {
            $0.connectedPeers = [
                WebRTCFeature.PeerState(id: "user123", connectionState: .connecting)
            ]
        }
    }

    func test_createPeerConnection_failure() async {
        let store = TestStore(initialState: WebRTCFeature.State()) {
            WebRTCFeature()
        } withDependencies: {
            $0.webRTCEngine.createPeerConnection = { _ in false }
        }

        await store.send(\.view, .createPeerConnection(userId: "user123"))
        await store.receive(.createPeerConnectionResult("user123", false))
        await store.receive(.errorOccurred(WebRTCError.peerConnectionNotFound, "user123")) {
            $0.error = .peerConnectionNotFound
        }
        await store.receive(\.delegate, .errorOccurred(.peerConnectionNotFound, userId: "user123"))
    }

    func test_removePeerConnection() async {
        let store = TestStore(
            initialState: WebRTCFeature.State(
                connectedPeers: [
                    WebRTCFeature.PeerState(id: "user123", connectionState: .connected)
                ]
            )
        ) {
            WebRTCFeature()
        } withDependencies: {
            $0.webRTCEngine.removePeerConnection = { _ in }
        }
        
        await store.send(\.view, .removePeerConnection(userId: "user123"))
        await store.receive(\.removePeerConnectionCompleted, "user123") {
            $0.connectedPeers = []
        }
        await store.receive(\.delegate, .videoTrackRemoved(userId: "user123"))
    }

    func test_createOffer_success() async {
        let store = TestStore(initialState: WebRTCFeature.State()) {
            WebRTCFeature()
        } withDependencies: {
            $0.webRTCEngine.createOffer = { _ in }
        }

        await store.send(\.view, .createOffer(userId: "user123"))
        await store.receive(\.offerCreated, "user123")
    }

    func test_createOffer_failure() async {
        let store = TestStore(initialState: WebRTCFeature.State()) {
            WebRTCFeature()
        } withDependencies: {
            $0.webRTCEngine.createOffer = { _ in throw WebRTCError.failedToCreateOffer }
        }

        await store.send(\.view, .createOffer(userId: "user123"))
        await store.receive(.errorOccurred(WebRTCError.failedToCreateOffer, "user123")) {
            $0.error = .failedToCreateOffer
        }
        await store.receive(\.delegate, .errorOccurred(.failedToCreateOffer, userId: "user123"))
    }

    func test_handleRemoteOffer_success() async {
        let mockOffer = RTCSessionDescription(type: .offer, sdp: "mock-offer-sdp")
        let mockAnswer = RTCSessionDescription(type: .answer, sdp: "mock-answer-sdp")

        let store = TestStore(initialState: WebRTCFeature.State()) {
            WebRTCFeature()
        } withDependencies: {
            $0.webRTCEngine.setRemoteOffer = { _, _ in mockAnswer }
        }

        await store.send(\.view, .handleRemoteOffer(mockOffer, userId: "user123"))
        await store.receive(.remoteOfferHandled("user123", mockAnswer))
    }

    func test_handleRemoteAnswer_success() async {
        let mockAnswer = RTCSessionDescription(type: .answer, sdp: "mock-answer-sdp")

        let store = TestStore(initialState: WebRTCFeature.State()) {
            WebRTCFeature()
        } withDependencies: {
            $0.webRTCEngine.setRemoteAnswer = { _, _ in }
        }

        await store.send(\.view, .handleRemoteAnswer(mockAnswer, userId: "user123"))
        await store.receive(\.remoteAnswerSet, "user123")
    }

    func test_handleICECandidate_success() async {
        let mockCandidate = RTCIceCandidate(
            sdp: "candidate:mock",
            sdpMLineIndex: 0,
            sdpMid: "0"
        )

        let store = TestStore(initialState: WebRTCFeature.State()) {
            WebRTCFeature()
        } withDependencies: {
            $0.webRTCEngine.addIceCandidate = { _, _ in }
        }

        await store.send(\.view, .handleICECandidate(mockCandidate, userId: "user123"))
        await store.receive(\.iceCandidateAdded, "user123")
    }

    func test_dismissError() async {
        let store = TestStore(
            initialState: WebRTCFeature.State(error: .peerConnectionNotFound)
        ) {
            WebRTCFeature()
        }

        await store.send(\.view, .dismissError) {
            $0.error = nil
        }
    }

    func test_webRTCEvent_offerGenerated() async {
        let store = TestStore(initialState: WebRTCFeature.State()) {
            WebRTCFeature()
        }

        let event = WebRTCEvent.offerGenerated(sdp: "mock-sdp", userId: "user123")
        await store.send(\.webRTCEvent, event)
        await store.receive(\.delegate, .offerGenerated(sdp: "mock-sdp", userId: "user123"))
    }

    func test_webRTCEvent_videoTrackAdded() async {
        let store = TestStore(initialState: WebRTCFeature.State()) {
            WebRTCFeature()
        }

        let trackInfo = VideoTrackInfo(id: "track1", userId: "user123", track: nil)
        let event = WebRTCEvent.videoTrackAdded(trackInfo: trackInfo)

        await store.send(\.webRTCEvent, event) {
            $0.connectedPeers = [
                WebRTCFeature.PeerState(
                    id: "user123",
                    videoTrack: trackInfo,
                    connectionState: .connected
                )
            ]
        }
        await store.receive(\.delegate, .videoTrackAdded(trackInfo))
    }

    func test_webRTCEvent_connectionStateChanged() async {
        let store = TestStore(
            initialState: WebRTCFeature.State(
                connectedPeers: [
                    WebRTCFeature.PeerState(id: "user123", connectionState: .connecting)
                ]
            )
        ) {
            WebRTCFeature()
        }

        let event = WebRTCEvent.connectionStateChanged(state: "connected", userId: "user123")

        await store.send(\.webRTCEvent, event) {
            $0.connectedPeers[id: "user123"]?.connectionState = .connected
        }
        await store.receive(
            \.delegate, .connectionStateChanged(userId: "user123", state: .connected))
    }
}
