//
//  WebRTCCoreTests.swift
//  WebRTCCore
//
//  Created by Claude on 2025/8/18.
//

import XCTest
@testable import WebRTCCore

final class WebRTCCoreTests: XCTestCase {

  func testWebRTCEngineInitialization() async {
    let engine = await MainActor.run { WebRTCEngine() }
    let connectedPeers = await MainActor.run { engine.connectedPeers }
    let videoTracks = await MainActor.run { engine.videoTracks }
    
    XCTAssertNotNil(engine)
    XCTAssertEqual(connectedPeers.count, 0)
    XCTAssertEqual(videoTracks.count, 0)
    XCTAssertNotNil(engine.events, "Events stream should be initialized")
  }

  func testVideoTrackInfoEquality() {
    let track1 = VideoTrackInfo(id: "1", userId: "user1", track: nil)
    let track2 = VideoTrackInfo(id: "1", userId: "user1", track: nil)
    let track3 = VideoTrackInfo(id: "2", userId: "user1", track: nil)

    XCTAssertEqual(track1, track2)
    XCTAssertNotEqual(track1, track3)
  }

  func testWebRTCErrorDescriptions() {
    XCTAssertEqual(WebRTCError.peerConnectionNotFound.errorDescription, "Peer connection not found")
    XCTAssertEqual(WebRTCError.failedToCreateOffer.errorDescription, "Failed to create offer")
    XCTAssertEqual(WebRTCError.failedToCreateAnswer.errorDescription, "Failed to create answer")
  }

  func testICECandidateModel() {
    let candidate = ICECandidate(
      type: "ice",
      clientId: "test-client",
      candidate: ICECandidate.Candidate(
        candidate: "test-candidate",
        sdpMLineIndex: 0,
        sdpMid: "0"
      )
    )

    XCTAssertEqual(candidate.type, "ice")
    XCTAssertEqual(candidate.clientId, "test-client")
    XCTAssertEqual(candidate.candidate.candidate, "test-candidate")
  }

  func testWebRTCEventEquality() {
    let event1 = WebRTCEvent.offerGenerated(sdp: "test-sdp", userId: "user1")
    let event2 = WebRTCEvent.offerGenerated(sdp: "test-sdp", userId: "user1")
    let event3 = WebRTCEvent.offerGenerated(sdp: "different-sdp", userId: "user1")

    XCTAssertEqual(event1, event2)
    XCTAssertNotEqual(event1, event3)
  }

  func testWebRTCEventTypes() {
    let offerEvent = WebRTCEvent.offerGenerated(sdp: "test-sdp", userId: "user1")
    let answerEvent = WebRTCEvent.answerGenerated(sdp: "test-sdp", userId: "user1")
    let iceEvent = WebRTCEvent.iceCandidateGenerated(candidate: "test", sdpMLineIndex: 0, sdpMid: "0", userId: "user1")
    let errorEvent = WebRTCEvent.errorOccurred(error: .peerConnectionNotFound, userId: "user1")

    // Test that events can be created and are different types
    XCTAssertNotEqual(offerEvent, answerEvent)
    XCTAssertNotEqual(iceEvent, errorEvent)
    
    // Test event properties
    switch offerEvent {
    case .offerGenerated(let sdp, let userId):
      XCTAssertEqual(sdp, "test-sdp")
      XCTAssertEqual(userId, "user1")
    default:
      XCTFail("Expected offerGenerated event")
    }
  }
}