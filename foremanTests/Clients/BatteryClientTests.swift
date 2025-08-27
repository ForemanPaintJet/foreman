//
//  BatteryClientTests.swift
//  foremanTests
//
//  Created by Claude on 2025/8/13.
//

import Combine
import ComposableArchitecture
import Foundation
import Testing

@testable import foreman

@Suite("BatteryClient")
@MainActor
struct BatteryClientTests {
  @Test("testValue client provides publisher")
  func testValueClient() async throws {
    let client = BatteryClient.testValue
    let publisher = client.batteryLevelPublisher()
    #expect(publisher != nil)
  }

  @Test("liveValue client provides publisher")
  func liveValueClient() async throws {
    let client = BatteryClient.liveValue
    let publisher = client.batteryLevelPublisher()
    #expect(publisher != nil)
  }

  @Test("custom client with immediate values")
  func customClient() async throws {
    let testValues = [100, 80, 60]
    let client = BatteryClient(
      batteryLevelPublisher: {
        testValues.publisher
          .eraseToAnyPublisher()
      }
    )

    var receivedValues: [Int] = []
    var didComplete = false

    let cancellable = client.batteryLevelPublisher()
      .sink(
        receiveCompletion: { completion in
          if case .finished = completion {
            didComplete = true
          }
        },
        receiveValue: { value in
          receivedValues.append(value)
        }
      )

    try await Task.sleep(for: .milliseconds(50))
    cancellable.cancel()

    #expect(receivedValues == testValues)
    #expect(didComplete)
  }

  @Test("dependency injection works")
  func dependencyInjection() async throws {
    await withDependencies {
      $0.batteryClient = BatteryClient.testValue
    } operation: {
      @Dependency(\.batteryClient) var batteryClient
      let publisher = batteryClient.batteryLevelPublisher()
      #expect(publisher != nil)
    }
  }

  @Test("battery level values are in valid range")
  func validRange() async throws {
    let testValues = [0, 25, 50, 75, 100]
    let client = BatteryClient(
      batteryLevelPublisher: {
        testValues.publisher
          .eraseToAnyPublisher()
      }
    )

    var receivedValues: [Int] = []
    let cancellable = client.batteryLevelPublisher()
      .sink { value in
        receivedValues.append(value)
      }

    try await Task.sleep(for: .milliseconds(50))
    cancellable.cancel()

    for value in receivedValues {
      #expect(value >= 0 && value <= 100)
    }
  }
}