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

@Suite("Foreman Specific Models")
struct ModelsTests {
  
  @Suite("MQTT Video Messages")
  struct MqttVideoMessagesTests {
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
    
    @Test("RequestVideoMessage different video sources")
    func testRequestVideoMessageVideoSources() async throws {
      let cameraRequest = RequestVideoMessage(clientId: "client1", videoSource: "camera")
      let screenRequest = RequestVideoMessage(clientId: "client1", videoSource: "screen")
      let micRequest = RequestVideoMessage(clientId: "client1", videoSource: "microphone")
      
      #expect(cameraRequest != screenRequest)
      #expect(screenRequest != micRequest)
      #expect(cameraRequest.videoSource == "camera")
      #expect(screenRequest.videoSource == "screen")
      #expect(micRequest.videoSource == "microphone")
    }
    
    @Test("LeaveVideoMessage different scenarios")
    func testLeaveVideoMessageScenarios() async throws {
      let cameraLeave = LeaveVideoMessage(clientId: "user1", videoSource: "camera")
      let screenLeave = LeaveVideoMessage(clientId: "user1", videoSource: "screen")
      let differentUserLeave = LeaveVideoMessage(clientId: "user2", videoSource: "camera")
      
      #expect(cameraLeave != screenLeave)
      #expect(cameraLeave != differentUserLeave)
      #expect(cameraLeave.clientId == "user1")
      #expect(differentUserLeave.clientId == "user2")
    }
  }
  
  @Suite("MQTT Configuration Models")
  struct MqttConfigurationTests {
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
    
    @Test("MqttClientKitInfo different ports and client IDs")
    func testMqttClientKitInfoVariations() async throws {
      let standardPort = MqttClientKitInfo(address: "broker.local", port: 1883, clientID: "client1")
      let securePort = MqttClientKitInfo(address: "broker.local", port: 8883, clientID: "client1")
      let differentClient = MqttClientKitInfo(address: "broker.local", port: 1883, clientID: "client2")
      
      #expect(standardPort != securePort)
      #expect(standardPort != differentClient)
      #expect(standardPort.port == 1883)
      #expect(securePort.port == 8883)
      #expect(differentClient.clientID == "client2")
    }
  }
  
  @Suite("MQTT Topic Constants")
  struct MqttTopicTests {
    @Test("MQTT topic constants are correct")
    func testMqttTopicConstants() async throws {
      #expect(inputTopic == "camera_system/streaming/in")
      #expect(outputTopic == "camera_system/streaming/out")
    }
  }
  
  @Suite("MQTT JSON Conversion Models")
  struct MqttJsonConversionTests {
    @Test("MqttWebRTCOffer converts from WebRTCOffer correctly")
    func testMqttWebRTCOfferConversion() async throws {
      let webRTCOffer = WebRTCOffer(
        sdp: "test-offer-sdp",
        type: "offer",
        from: "client123",
        to: "server456",
        videoSource: "camera"
      )
      
      let mqttOffer = MqttWebRTCOffer(from: webRTCOffer)
      
      #expect(mqttOffer.sdp == "test-offer-sdp")
      #expect(mqttOffer.type == "offer")
      #expect(mqttOffer.clientId == "client123")  // from -> clientId
      #expect(mqttOffer.videoSource == "camera")
    }
    
    @Test("MqttWebRTCAnswer converts from WebRTCAnswer correctly")
    func testMqttWebRTCAnswerConversion() async throws {
      let webRTCAnswer = WebRTCAnswer(
        sdp: "test-answer-sdp",
        type: "answer",
        from: "server456",
        to: "client123",
        videoSource: "screen"
      )
      
      let mqttAnswer = MqttWebRTCAnswer(from: webRTCAnswer)
      
      #expect(mqttAnswer.sdp == "test-answer-sdp")
      #expect(mqttAnswer.type == "answer")
      #expect(mqttAnswer.clientId == "server456")  // from -> clientId
      #expect(mqttAnswer.videoSource == "screen")
    }
    
    @Test("MqttICECandidate converts from ICECandidate correctly")
    func testMqttICECandidateConversion() async throws {
      let iceCandidate = ICECandidate(
        type: "ice",
        from: "client123",
        to: "server456",
        candidate: ICECandidate.Candidate(
          candidate: "candidate:test-ice-data",
          sdpMLineIndex: 0,
          sdpMid: "0"
        )
      )
      
      let mqttCandidate = MqttICECandidate(from: iceCandidate)
      
      #expect(mqttCandidate.type == "ice")
      #expect(mqttCandidate.clientId == "client123")  // from -> clientId
      #expect(mqttCandidate.candidate.candidate == "candidate:test-ice-data")
      #expect(mqttCandidate.candidate.sdpMLineIndex == 0)
      #expect(mqttCandidate.candidate.sdpMid == "0")
    }
    
    @Test("MQTT models are JSON serializable with clientId format")
    func testMqttModelsJSONSerialization() async throws {
      let webRTCOffer = WebRTCOffer(
        sdp: "test-sdp",
        type: "offer",
        from: "user123",
        to: "server",
        videoSource: "camera"
      )
      
      let mqttOffer = MqttWebRTCOffer(from: webRTCOffer)
      let jsonData = try JSONEncoder().encode(mqttOffer)
      let jsonString = String(data: jsonData, encoding: .utf8)!
      
      // Verify JSON contains clientId (not from/to)
      #expect(jsonString.contains("\"clientId\":\"user123\""))
      #expect(!jsonString.contains("\"from\""))
      #expect(!jsonString.contains("\"to\""))
      #expect(jsonString.contains("\"sdp\":\"test-sdp\""))
      #expect(jsonString.contains("\"type\":\"offer\""))
      #expect(jsonString.contains("\"videoSource\":\"camera\""))
    }
    
    @Test("MQTT models round-trip JSON serialization")
    func testMqttModelsRoundTripSerialization() async throws {
      let originalOffer = MqttWebRTCOffer(
        from: WebRTCOffer(
          sdp: "test-sdp",
          type: "offer", 
          from: "client1",
          to: "server",
          videoSource: "camera"
        )
      )
      
      // Serialize to JSON
      let jsonData = try JSONEncoder().encode(originalOffer)
      
      // Deserialize back
      let decodedOffer = try JSONDecoder().decode(MqttWebRTCOffer.self, from: jsonData)
      
      #expect(decodedOffer == originalOffer)
      #expect(decodedOffer.clientId == "client1")
    }
  }
}