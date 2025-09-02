//
//  MqttClientKit+PreviewValues.swift
//  foreman
//
//  Created by Claude on 2025/9/2.
//

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
            while !Task.isCancelled {
              let randomInt = Int.random(in: 1...100)
              let mockPayload = "\(randomInt)".data(using: .utf8) ?? Data()
              
              // Create mock MQTTPublishInfo with random int value
            let mockMessage = MQTTPublishInfo(qos: .atMostOnce, retain: false, topicName: "network/ifstat/data", payload: ByteBuffer(data: mockPayload), properties: [])
              
              continuation.yield(mockMessage)
              
              try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
            continuation.finish()
          }
        }
      }
    )
  }
}
