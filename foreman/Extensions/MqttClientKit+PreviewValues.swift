//
//  MqttClientKit+PreviewValues.swift
//  foreman
//
//  Created by Claude on 2025/9/2.
//

import Foundation
import MqttClientKit
import SwiftUI
import NIOCore
import MQTTNIO

extension MqttClientKit {
  /// Preview value for SwiftUI previews with mock implementations
  static var previewValue: MqttClientKit {
    MqttClientKit(
      connect: { _ in
        AsyncStream { continuation in
          continuation.yield(.connecting)
          Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            continuation.yield(.connected)
            continuation.finish()
          }
        }
      },
      disconnect: {
        // Mock disconnect - does nothing in preview
      },
      publish: { _ in
        // Mock publish - does nothing in preview
      },
      subscribe: { _ in
        // Mock subscribe - returns nil in preview
        return nil
      },
      unsubscribe: { _ in
        // Mock unsubscribe - does nothing in preview
      },
      isActive: {
        // Mock isActive - returns true in preview
        return true
      },
      received: {
        AsyncThrowingStream { continuation in
          Task {
            // All monitoring topics with their mock data generators
            let topics = [
              (topic: ifstatOutputTopic, generator: { Int.random(in: 1...100) }),
              (topic: "monitoring/cpu", generator: { Int.random(in: 0...100) }),
              (topic: "monitoring/memory", generator: { Int.random(in: 100...8000) }),
              (topic: "monitoring/disk", generator: { Int.random(in: 0...500) }),
              (topic: "monitoring/temperature", generator: { Int.random(in: 25...80) })
            ]
            
            var currentTopicIndex = 0
            
            while !Task.isCancelled {
              let currentTopic = topics[currentTopicIndex]
              let mockValue = currentTopic.generator()
              let currentTimestamp = Date().timeIntervalSince1970
              
              // Create IfstatMqttMessage with topic-appropriate mock value
              let ifstatMessage = IfstatMqttMessage(
                value: mockValue, 
                timestamp: Date(timeIntervalSince1970: currentTimestamp)
              )
              
              // Encode to JSON data matching the expected format
              let encoder = JSONEncoder()
              encoder.dateEncodingStrategy = .secondsSince1970
              let mockPayload = try! encoder.encode(ifstatMessage)
              
              // Create mock MQTTPublishInfo with current topic
              let mockMessage = MQTTPublishInfo(qos: .atMostOnce, retain: false, topicName: currentTopic.topic, payload: ByteBuffer(data: mockPayload), properties: [])
              
              continuation.yield(mockMessage)
              
              // Cycle through all topics
              currentTopicIndex = (currentTopicIndex + 1) % topics.count
              
              try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
            continuation.finish()
          }
        }
      }
    )
  }
}
