//
//  ModelsTests.swift
//  foremanTests
//
//  Created by Claude on 2025/8/13.
//

import Testing
import WebRTC
import MqttClientKit
import WebRTCCore

@testable import foreman

@Suite("Models")
struct ModelsTests {
  
  @Suite("WebRTC Models")
  struct WebRTCModelsTests {
    @Test("WebRTCOffer equality and properties")
    func testWebRTCOffer() async throws {
      let offer1 = WebRTCOffer(sdp: "test-sdp", type: "offer", clientId: "client1", videoSource: "camera")
      let offer2 = WebRTCOffer(sdp: "test-sdp", type: "offer", clientId: "client1", videoSource: "camera")
      let offer3 = WebRTCOffer(sdp: "different-sdp", type: "offer", clientId: "client1", videoSource: "camera")
      
      #expect(offer1 == offer2)
      #expect(offer1 != offer3)
      #expect(offer1.sdp == "test-sdp")
      #expect(offer1.type == "offer")
      #expect(offer1.clientId == "client1")
      #expect(offer1.videoSource == "camera")
    }

    @Test("WebRTCAnswer equality and properties")
    func testWebRTCAnswer() async throws {
      let answer1 = WebRTCAnswer(sdp: "test-sdp", type: "answer", clientId: "client1", videoSource: "screen")
      let answer2 = WebRTCAnswer(sdp: "test-sdp", type: "answer", clientId: "client1", videoSource: "screen")
      let answer3 = WebRTCAnswer(sdp: "test-sdp", type: "answer", clientId: "client2", videoSource: "screen")
      
      #expect(answer1 == answer2)
      #expect(answer1 != answer3)
      #expect(answer1.sdp == "test-sdp")
      #expect(answer1.type == "answer")
      #expect(answer1.clientId == "client1")
      #expect(answer1.videoSource == "screen")
    }

    @Test("ICECandidate nested structure")
    func testICECandidate() async throws {
      let candidate = ICECandidate.Candidate(
        candidate: "candidate:1 1 UDP 2130706431 192.168.1.100 54400 typ host",
        sdpMLineIndex: 0,
        sdpMid: "0"
      )
      
      let iceCandidate1 = ICECandidate(type: "ice", clientId: "client1", candidate: candidate)
      let iceCandidate2 = ICECandidate(type: "ice", clientId: "client1", candidate: candidate)
      let iceCandidate3 = ICECandidate(type: "ice", clientId: "client2", candidate: candidate)
      
      #expect(iceCandidate1 == iceCandidate2)
      #expect(iceCandidate1 != iceCandidate3)
      #expect(iceCandidate1.type == "ice")
      #expect(iceCandidate1.clientId == "client1")
      #expect(iceCandidate1.candidate.candidate.contains("192.168.1.100"))
      #expect(iceCandidate1.candidate.sdpMLineIndex == 0)
      #expect(iceCandidate1.candidate.sdpMid == "0")
    }
    
    @Test("VideoTrackInfo equality")
    func testVideoTrackInfo() async throws {
      let track1 = VideoTrackInfo(id: "track1", userId: "user1", track: nil)
      let track2 = VideoTrackInfo(id: "track1", userId: "user1", track: nil)
      let track3 = VideoTrackInfo(id: "track2", userId: "user1", track: nil)
      let track4 = VideoTrackInfo(id: "track1", userId: "user2", track: nil)
      
      #expect(track1 == track2)
      #expect(track1 != track3)
      #expect(track1 != track4)
      #expect(track1.id == "track1")
      #expect(track1.userId == "user1")
    }
    
    @Test("PeerConnectionInfo properties")
    func testPeerConnectionInfo() async throws {
      let info1 = PeerConnectionInfo(userId: "user1", connectionState: .connected)
      let info2 = PeerConnectionInfo(userId: "user1", connectionState: .connected)
      let info3 = PeerConnectionInfo(userId: "user1", connectionState: .disconnected)
      
      #expect(info1 == info2)
      #expect(info1 != info3)
      #expect(info1.userId == "user1")
      #expect(info1.connectionState == .connected)
    }
  }
    
    @Test("RequestVideoMessage properties")
    func testRequestVideoMessage() async throws {
      let request1 = RequestVideoMessage(clientId: "client1", videoSource: "camera")
      let request2 = RequestVideoMessage(clientId: "client1", videoSource: "camera")
      let request3 = RequestVideoMessage(clientId: "client2", videoSource: "camera")
      
      #expect(request1 == request2)
      #expect(request1 != request3)
      #expect(request1.type == "requestVideo")
      #expect(request1.clientId == "client1")
      #expect(request1.videoSource == "camera")
    }
    
    @Test("LeaveVideoMessage properties")
    func testLeaveVideoMessage() async throws {
      let leave1 = LeaveVideoMessage(clientId: "client1", videoSource: "screen")
      let leave2 = LeaveVideoMessage(clientId: "client1", videoSource: "screen")
      let leave3 = LeaveVideoMessage(clientId: "client1", videoSource: "camera")
      
      #expect(leave1 == leave2)
      #expect(leave1 != leave3)
      #expect(leave1.type == "leaveVideo")
      #expect(leave1.clientId == "client1")
      #expect(leave1.videoSource == "screen")
    }
  }
  
  @Suite("WebRTC Errors")
  struct WebRTCErrorsTests {
    @Test("WebRTCError cases and descriptions")
    func testWebRTCError() async throws {
      let error1 = WebRTCError.peerConnectionNotFound
      let error2 = WebRTCError.failedToCreateOffer
      let error3 = WebRTCError.failedToCreateAnswer
      let error4 = WebRTCError.failedToSetDescription
      let error5 = WebRTCError.failedToAddCandidate
      
      #expect(error1.errorDescription == "Peer connection not found")
      #expect(error2.errorDescription == "Failed to create offer")
      #expect(error3.errorDescription == "Failed to create answer")
      #expect(error4.errorDescription == "Failed to set session description")
      #expect(error5.errorDescription == "Failed to add ICE candidate")
    }
  }
  
  @Suite("MQTT Models")
  struct MqttModelsTests {
    @Test("MqttClientKitInfo properties")
    func testMqttClientKitInfo() async throws {
      let info1 = MqttClientKitInfo(address: "192.168.1.100", port: 1883, clientID: "client1")
      let info2 = MqttClientKitInfo(address: "192.168.1.100", port: 1883, clientID: "client1")
      let info3 = MqttClientKitInfo(address: "192.168.1.101", port: 1883, clientID: "client1")
      
      #expect(info1 == info2)
      #expect(info1 != info3)
      #expect(info1.address == "192.168.1.100")
      #expect(info1.port == 1883)
      #expect(info1.clientID == "client1")
    }
  }
