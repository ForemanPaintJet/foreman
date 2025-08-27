//
//  SplashFeatureTests.swift
//  foremanTests
//
//  Created by Claude on 2025/8/27.
//

import ComposableArchitecture
import Testing

@testable import foreman

@Suite("SplashFeature")
@MainActor
struct SplashFeatureTests {
  
  @Test("initial state has correct logoRotationAngle")
  func testInitialState() async throws {
    let state = SplashFeature.State()
    #expect(state.logoRotationAngle == 90.0)
  }
  
  @Test("task triggers splashCompleted after 1 second")
  func testTaskTriggersCompletion() async throws {
    let clock = TestClock()
    
    let store = TestStore(
      initialState: SplashFeature.State()
    ) {
      SplashFeature()
    } withDependencies: {
      $0.continuousClock = clock
    }
    
    // Send task action
    await store.send(.view(.task))
    
    // Advance clock by 1 second
    await clock.advance(by: .seconds(1))
    
    // Should receive splashCompleted delegate action
    await store.receive(\.delegate, .splashCompleted)
  }
  
  @Test("splashCompleted delegate cancels timer effect")
  func testSplashCompletedCancelsTimer() async throws {
    let clock = TestClock()
    
    let store = TestStore(
      initialState: SplashFeature.State()
    ) {
      SplashFeature()
    } withDependencies: {
      $0.continuousClock = clock
    }
    
    // Send task action
    await store.send(.view(.task))
    
    // Complete the timer
    await clock.advance(by: .seconds(1))
    
    // Should receive splashCompleted and effect should be properly cleaned up
    await store.receive(\.delegate, .splashCompleted)
    
    // After receiving splashCompleted, the timer effect should be cancelled
    // This is verified by store.finish() succeeding
    await store.finish()
  }
  
  @Test("logoRotationAngle remains constant during task")
  func testLogoRotationAngleStability() async throws {
    let clock = TestClock()
    
    let store = TestStore(
      initialState: SplashFeature.State()
    ) {
      SplashFeature()
    } withDependencies: {
      $0.continuousClock = clock
    }
    
    // Initial angle should be 90.0
    #expect(store.state.logoRotationAngle == 90.0)
    
    // Send task action
    await store.send(.view(.task))
    
    // Advance partway through
    await clock.advance(by: .milliseconds(500))
    
    // Angle should remain unchanged
    #expect(store.state.logoRotationAngle == 90.0)
    
    // Complete the task
    await clock.advance(by: .milliseconds(500))
    await store.receive(\.delegate, .splashCompleted)
    
    // Angle should still be unchanged
    #expect(store.state.logoRotationAngle == 90.0)
  }
  
}
