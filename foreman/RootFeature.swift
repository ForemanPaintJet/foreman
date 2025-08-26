//
//  RootFeature.swift
//  foreman
//
//  Created by Claude on 2025/8/26.
//

import ComposableArchitecture
import OSLog

@Reducer
struct RootFeature {
  @Dependency(\.continuousClock) var clock
  @ObservableState
  struct State: Equatable {
    var splash: SplashFeature.State?
    var webRTCMqtt: WebRTCMqttFeature.State?
    
    init() {
      self.splash = SplashFeature.State()
    }
  }
  
  @CasePathable
  enum Action: Equatable {
    case splash(SplashFeature.Action)
    case webRTCMqtt(WebRTCMqttFeature.Action)
    case transitionCompleted
  }
  
  init() {}
  
  var body: some ReducerOf<Self> {
    Reduce(core)
      .ifLet(\.splash, action: \.splash) {
        SplashFeature()
      }
      .ifLet(\.webRTCMqtt, action: \.webRTCMqtt) {
        WebRTCMqttFeature()
      }
  }
  
  private enum CancelID { case transition }
  
  func core(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .splash(.delegate(.splashCompleted)):
      // 立即創建 WebRTC view
      state.webRTCMqtt = WebRTCMqttFeature.State()
      return .run { [clock = self.clock] send in
        try await clock.sleep(for: .seconds(1)) // 1秒的過渡時間
          await send(.transitionCompleted, animation: .default)
      }
      .cancellable(id: CancelID.transition)
      
    case .transitionCompleted:
      state.splash = nil
      return .none
      
    case .splash:
      return .none
      
    case .webRTCMqtt:
      return .none
    }
  }
}
