//
//  SplashFeature.swift
//  foreman
//
//  Created by Claude on 2025/8/26.
//

import ComposableArchitecture
import Foundation
import OSLog

@Reducer
struct SplashFeature {
  @Dependency(\.continuousClock) var clock
  @ObservableState
  struct State: Equatable {
    var isLoading = true
    var animationProgress: Double = 0.0
    var scaleAmount: Double = 0.0
    var isTransitioning = false
    var startTime: Date?
    
    init() {}
  }
  
  @CasePathable
  enum Action: Equatable, ViewAction {
    case view(ViewAction)
    case delegate(Delegate)
    
    @CasePathable
    enum ViewAction: Equatable {
      case task
      case timerTick
      case startTransition
    }
    
    @CasePathable
    enum Delegate: Equatable {
      case splashCompleted
    }
  }
  
  init() {}
  
  private enum CancelID { case timer }
  
  var body: some ReducerOf<Self> {
    Reduce(core)
  }
  
  func core(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .view(.task):
      state.startTime = Date()
      return .run { [clock = self.clock] send in
        for await _ in clock.timer(interval: .milliseconds(16)) { // 60 FPS
          await send(.view(.timerTick))
        }
      }
      .cancellable(id: CancelID.timer)
      
    case .view(.timerTick):
      guard let startTime = state.startTime else { return .none }
      
      let elapsed = Date().timeIntervalSince(startTime)
      let totalDuration: TimeInterval = 2.0 // 2 秒動畫
      let progress = min(elapsed / totalDuration, 1.0)
      
      state.animationProgress = progress
      
      // 縮放動畫：先變大(到1.5倍)再變小，形成鐘擺效果
        if progress <= 0.5 {
            // 前半段：從0放大到1.5
            state.scaleAmount = progress * 3.0 // 0 -> 1.5
        }
      
      if progress >= 1.0 {
        state.isLoading = false
        return .run { send in
          await send(.view(.startTransition), animation: .spring(duration: 0.8))
        }
        .cancellable(id: CancelID.timer)
      }
      
      return .none
      
    case .view(.startTransition):
      state.isTransitioning = true
      return .concatenate(
        .cancel(id: CancelID.timer),
        .run { send in
          await send(.delegate(.splashCompleted))
        }
      )
      
    case .delegate:
      return .none
    }
  }
}
