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
}