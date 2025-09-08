//
//  DashboardFeature.swift
//  foreman
//
//  Created by Claude on 2025/9/5.
//

import ComposableArchitecture
import OSLog

@Reducer
struct DashboardFeature {
  @ObservableState
  struct State: Equatable {
    // Main video call state
    var directVideoCall: DirectVideoCallFeature.State = .init()
    
    // 使用 IdentifiedArray 管理所有 ifstat 監控項目
    var monitoringItems: IdentifiedArrayOf<IfstatFeature.State> = IdentifiedArrayOf(
      uniqueElements: [
        IfstatFeature.State(
          topicName: ifstatOutputTopic,
          displayName: "Network Speed",
          unit: "bytes/s",
          isMiniMode: true
        ),
        IfstatFeature.State(
          topicName: "monitoring/cpu",
          displayName: "CPU Usage",
          unit: "%",
          isMiniMode: true
        ),
        IfstatFeature.State(
          topicName: "monitoring/memory",
          displayName: "Memory Usage",
          unit: "MB",
          isMiniMode: true
        ),
        IfstatFeature.State(
          topicName: "monitoring/disk",
          displayName: "Disk I/O",
          unit: "MB/s",
          isMiniMode: true
        ),
        IfstatFeature.State(
          topicName: "monitoring/temperature",
          displayName: "Temperature",
          unit: "°C",
          isMiniMode: true
        )
      ]
    )
    
    // Sensor status 保持獨立（因為是不同類型的 Feature）
    var sensorNodeStatus: SensorNodeStatusFeature.State = SensorNodeStatusFeature.State(isMiniMode: true)
    
    // Drawer state
    var isDrawerOpen: Bool = false
    var drawerWidth: CGFloat = 350
    
    // Layout state
    var isCompactLayout: Bool = false
    
    // Mini mode state
    var isMiniMode: Bool = true
  }
  
  @CasePathable
  enum Action: Equatable, BindableAction, ComposableArchitecture.ViewAction {
    case view(ViewAction)
    case binding(BindingAction<State>)
    case _internal(InternalAction)
    case delegate(DelegateAction)
    
    // Child feature actions
    case directVideoCall(DirectVideoCallFeature.Action)
    case monitoringItems(IdentifiedActionOf<IfstatFeature>)
    case sensorNodeStatus(SensorNodeStatusFeature.Action)
    
    @CasePathable
    enum ViewAction: Equatable {
      case task
      case teardown
      case toggleDrawer
      case setDrawerOpen(Bool)
      case setDrawerWidth(CGFloat)
      case setCompactLayout(Bool)
      case toggleMiniMode
      case setMiniMode(Bool)
    }
    
    @CasePathable
    enum InternalAction: Equatable {
      case updateDrawerState
    }
    
    @CasePathable
    enum DelegateAction: Equatable {
      case dataUpdated
    }
  }
  
  private let logger = Logger(subsystem: "foreman", category: "DashboardFeature")
  
  var body: some ReducerOf<Self> {
    BindingReducer()
    
    Scope(state: \.directVideoCall, action: \.directVideoCall) {
      DirectVideoCallFeature()
    }
    
    Scope(state: \.sensorNodeStatus, action: \.sensorNodeStatus) {
      SensorNodeStatusFeature()
    }
    
    Reduce(core)
      .forEach(\.monitoringItems, action: \.monitoringItems) {
        IfstatFeature()
      }
  }
  
  func core(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .binding:
      return .none
      
    case .view(.task):
      // Initialize all child features
      let monitoringEffects = state.monitoringItems.ids.map { id in
        Effect<Action>.send(.monitoringItems(.element(id: id, action: .view(.task))))
      }
      
      // Sync initial miniMode state to all child features
      let syncMiniModeEffects = state.monitoringItems.ids.map { id in
        Effect<Action>.send(.monitoringItems(.element(id: id, action: .view(.setMiniMode(state.isMiniMode)))))
      }
      
      return .merge([
        .send(.directVideoCall(.view(.task))),
        .send(.sensorNodeStatus(.view(.task))),
        .send(.sensorNodeStatus(.view(.setMiniMode(state.isMiniMode))))
      ] + monitoringEffects + syncMiniModeEffects)
      
    case .view(.toggleDrawer):
      let isDrawerOpen = state.isDrawerOpen
      state.isDrawerOpen.toggle()
      logger.info("🎛️ DashboardFeature: Drawer toggled to \(isDrawerOpen ? "open" : "closed")")
      return .none
      
    case .view(.setDrawerOpen(let isOpen)):
      state.isDrawerOpen = isOpen
      return .none
      
    case .view(.setDrawerWidth(let width)):
      state.drawerWidth = max(250, min(500, width)) // Clamp between 250-500
      return .none
      
    case .view(.setCompactLayout(let isCompact)):
      state.isCompactLayout = isCompact
      if isCompact && state.isDrawerOpen {
        // Auto-close drawer in compact layout
        state.isDrawerOpen = false
      }
      return .none
      
    case .view(.toggleMiniMode):
      let isMiniMode = state.isMiniMode
      state.isMiniMode.toggle()
      logger.info("🔄 DashboardFeature: Mini mode toggled to \(isMiniMode ? "mini" : "full")")
      
      // Sync mini mode to all child features
      let syncEffects = state.monitoringItems.ids.map { id in
        Effect<Action>.send(.monitoringItems(.element(id: id, action: .view(.setMiniMode(state.isMiniMode)))))
      }
      
      return .merge(syncEffects + [
        .send(.sensorNodeStatus(.view(.setMiniMode(state.isMiniMode))))
      ])
      
    case .view(.setMiniMode(let isMini)):
      state.isMiniMode = isMini
      
      // Sync mini mode to all child features
      let syncEffects = state.monitoringItems.ids.map { id in
        Effect<Action>.send(.monitoringItems(.element(id: id, action: .view(.setMiniMode(isMini)))))
      }
      
      return .merge(syncEffects + [
        .send(.sensorNodeStatus(.view(.setMiniMode(isMini))))
      ])
      
    case .view(.teardown):
      // Teardown all child monitoring features
      let teardownEffects = state.monitoringItems.ids.map { id in
        Effect<Action>.send(.monitoringItems(.element(id: id, action: .view(.teardown))))
      }
      
      return .merge(teardownEffects + [
        .send(.sensorNodeStatus(.view(.teardown)))
      ])
      
    case ._internal(.updateDrawerState):
      return .none
      
    case .delegate:
      return .none
      
    // Handle child feature delegate actions
    case .directVideoCall(.delegate):
      return .none
      
    case .monitoringItems(.element(id: let id, action: .delegate(.dataUpdated))):
      logger.info("📊 DashboardFeature: Monitoring item \(id) data updated")
      return .send(.delegate(.dataUpdated))
      
    case .sensorNodeStatus(.delegate(.statusUpdated)):
      logger.info("🟢 DashboardFeature: Sensor status updated")
      return .send(.delegate(.dataUpdated))
      
    // Pass through child feature actions
    case .directVideoCall, .monitoringItems, .sensorNodeStatus:
      return .none
    }
  }
}
