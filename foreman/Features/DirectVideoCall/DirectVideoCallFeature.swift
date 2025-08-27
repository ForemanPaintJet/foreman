//
//  DirectVideoCallFeature.swift
//  foreman
//
//  Created by Jed Lu on 2025/7/22.
//

import ComposableArchitecture
import OSLog
import SwiftUI
import WebRTCCore

@Reducer
struct DirectVideoCallFeature {
  @ObservableState
  struct State: Equatable {
    var showConfig: Bool = false
    var showHumanPose: Bool = false
    var showWifiDetails: Bool = false
    var distanceFt: Double = 10.0
    var batteryLevel: Int = 100
    var wifiSignalStrength: Int = -45  // dBm
    var connectionQuality: Double = 0.85  // 0-1
    var networkSpeed: Double = 150.5  // Mbps
    var latency: Int = 12  // ms

    // Alert system
    var currentAlert: AlertType = .none
    
    // WebRTC state
    var remoteVideoTracks: [VideoTrackInfo] = []

    enum AlertType: String, CaseIterable, Equatable {
      case none = "None"
      case green = "Green"
      case yellow = "Yellow"
      case red = "Red"

      var color: Color {
        switch self {
        case .none: .clear
        case .green: .green
        case .yellow: .yellow
        case .red: .red
        }
      }

      var message: String {
        switch self {
        case .none: ""
        case .green: "System Normal"
        case .yellow: "Warning Alert"
        case .red: "Critical Alert"
        }
      }
    }
  }

  @CasePathable
  enum Action: Equatable, BindableAction, ComposableArchitecture.ViewAction {
    case view(ViewAction)
    case binding(BindingAction<State>)
    case _internal(InternalAction)
    case delegate(DelegateAction)

    @CasePathable
    enum ViewAction: Equatable {
      case task
      case showConfig(Bool)
      case showHumanPose(Bool)
      case toggleWifiDetails
      case updateDistanceRandom
      case closeConfig
      case closeHumanPose
      case simulateAlert(State.AlertType)
    }

    @CasePathable
    enum InternalAction: Equatable {
      case batteryLevelChanged(Int)
    }

    enum DelegateAction: Equatable {
      // For future delegate logic
    }
  }

  enum CancelID {
    case battery
  }

  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce(core)
  }

  func core(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .binding:
      return .none
    case .view(.task):
      // Start battery monitoring
      return .run { send in
        @Dependency(\.batteryClient) var batteryClient
        for await batteryLevel in batteryClient.batteryLevelPublisher().values {
          await send(._internal(.batteryLevelChanged(batteryLevel)))
        }
      }
      .cancellable(id: CancelID.battery)
    case .view(.showConfig(let show)):
      state.showConfig = show
      return .none
    case .view(.showHumanPose(let show)):
      state.showHumanPose = show
      return .none
    case .view(.toggleWifiDetails):
      state.showWifiDetails.toggle()
      return .none
    case .view(.updateDistanceRandom):
      state.distanceFt = Double.random(in: 1...100)
      return .none
    case .view(.closeConfig):
      state.showConfig = false
      return .none
    case .view(.closeHumanPose):
      state.showHumanPose = false
      return .none
    case .view(.simulateAlert(let alertType)):
      state.currentAlert = alertType
      return .none
    case ._internal(.batteryLevelChanged(let value)):
      state.batteryLevel = value
      return .none
    case .delegate:
      return .none
    }
  }
}