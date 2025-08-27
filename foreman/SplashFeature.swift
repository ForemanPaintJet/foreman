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
      return .run { [clock = self.clock] send in
        try await clock.sleep(for: .seconds(1)) // 顯示 1 秒
        await send(.delegate(.splashCompleted), animation: .easeInOut(duration: 0.5))
      }
      .cancellable(id: CancelID.timer)
      
    case .delegate(.splashCompleted):
      return .cancel(id: CancelID.timer)
      
    case .delegate:
      return .none
    }
  }
}
