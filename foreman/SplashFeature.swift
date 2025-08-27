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
  @ObservableState
  struct State: Equatable {
    var logoRotationAngle: Double = 90.0
  }
  
  @CasePathable
  enum Action: Equatable, ViewAction {
    case view(ViewAction)
    case delegate(Delegate)
    
    @CasePathable
    enum ViewAction: Equatable {
      case task
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
      return .run { send in
        @Dependency(\.continuousClock) var clock
        do {
          try await clock.sleep(for: .seconds(1)) // Display for 1 second
          await send(.delegate(.splashCompleted), animation: .easeInOut(duration: 0.5))
        } catch {
          // Handle cancellation gracefully - no action needed as effect is being cancelled
        }
      }
      .cancellable(id: CancelID.timer)
      
    case .delegate(.splashCompleted):
      return .cancel(id: CancelID.timer)
      
    case .delegate:
      return .none
    }
  }
}
