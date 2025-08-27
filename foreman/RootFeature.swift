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
  @ObservableState
  struct State: Equatable {
    var splash: SplashFeature.State?
    var webRTCMqtt: WebRTCMqttFeature.State?
    var logoRotationAngle: Double = 180.0
  }
  
  @CasePathable
  enum Action: Equatable {
    case task
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
    case .task:
        state.splash = SplashFeature.State(logoRotationAngle: state.logoRotationAngle)
        return .none
    case .splash(.delegate(.splashCompleted)):
        state.webRTCMqtt = WebRTCMqttFeature.State(logoRotationAngle: state.logoRotationAngle)
      return .run { send in
          await send(.transitionCompleted, animation: .easeInOut(duration: 1.0))
      }
      .cancellable(id: CancelID.transition)
      
    case .transitionCompleted:
      state.splash = nil
      return .run { send in
        await send(.webRTCMqtt(.view(.resetLogoRotation)), animation: .bouncy)
      }
      
    case .splash:
      return .none
      
    case .webRTCMqtt:
      return .none
    }
  }
}
