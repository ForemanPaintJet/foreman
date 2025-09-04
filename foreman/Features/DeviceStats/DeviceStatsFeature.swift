//
//  DeviceStatsFeature.swift
//  foreman
//
//  Created by Claude on 2025/8/28.
//

import ComposableArchitecture
import Foundation
import OSLog

@Reducer
struct DeviceStatsFeature {
  @ObservableState
  struct State: Equatable {
    var deviceData: [DeviceSpeedData] = []
    var timeRange: DeviceSpeedChartView.TimeRange = .fiveMinutes
    var currentMetrics: NetworkMetrics = .empty
    var trendData: [TrendDataPoint] = []
    var isAutoRefreshEnabled: Bool = true
    var lastRefreshTime: Date = Date()
    
    var availableDevices: [String] {
      Array(Set(deviceData.map(\.deviceId))).sorted()
    }
    
    var filteredDeviceData: [DeviceSpeedData] {
      let cutoffTime = Date().addingTimeInterval(-timeRange.duration)
      return deviceData.filter { $0.timestamp >= cutoffTime }
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
      case teardown
      case refreshData
      case changeTimeRange(DeviceSpeedChartView.TimeRange)
      case toggleAutoRefresh
    }
    
    @CasePathable
    enum InternalAction: Equatable {
      case deviceDataUpdated([DeviceSpeedData])
      case metricsCalculated(NetworkMetrics)
      case trendDataUpdated([TrendDataPoint])
      case autoRefreshTick
    }
    
    enum DelegateAction: Equatable {
      case metricsUpdated(NetworkMetrics)
    }
  }
  
  private enum CancelID {
    case autoRefresh
  }
  
  private let logger = Logger(subsystem: "foreman", category: "DeviceStatsFeature")
  
  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce(core)
  }
  
  func core(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .binding:
      return .none
      
    case .view(let viewAction):
      return handleViewAction(into: &state, action: viewAction)
      
    case ._internal(let internalAction):
      return handleInternalAction(into: &state, action: internalAction)
      
    case .delegate:
      return .none
    }
  }
  
  private func handleViewAction(into state: inout State, action: Action.ViewAction) -> Effect<Action> {
    switch action {
    case .task:
      logger.info("🔄 DeviceStatsFeature: Starting task")
      
      let autoRefreshEffect: Effect<Action> = state.isAutoRefreshEnabled
        ? .run { send in
            for await _ in Timer.publish(every: 2.0, on: .main, in: .common).autoconnect().values {
              await send(._internal(.autoRefreshTick))
            }
          }
          .cancellable(id: CancelID.autoRefresh)
        : .none
      
      return .merge(
        .send(.view(.refreshData)),
        autoRefreshEffect
      )
      
    case .teardown:
      return .cancel(id: CancelID.autoRefresh)
      
    case .refreshData:
      logger.info("🔄 DeviceStatsFeature: Refreshing data")
      state.lastRefreshTime = Date()
      
      let mockData = generateMockDeviceData()
      return .send(._internal(.deviceDataUpdated(mockData)))
      
    case .changeTimeRange(let newRange):
      state.timeRange = newRange
      return .send(.view(.refreshData))
      
    case .toggleAutoRefresh:
      state.isAutoRefreshEnabled.toggle()
      
      if state.isAutoRefreshEnabled {
        return .run { send in
          for await _ in Timer.publish(every: 2.0, on: .main, in: .common).autoconnect().values {
            await send(._internal(.autoRefreshTick))
          }
        }
        .cancellable(id: CancelID.autoRefresh)
      } else {
        return .cancel(id: CancelID.autoRefresh)
      }
    }
  }
  
  private func handleInternalAction(into state: inout State, action: Action.InternalAction) -> Effect<Action> {
    switch action {
    case .deviceDataUpdated(let newData):
      state.deviceData = mergeDeviceData(existing: state.deviceData, new: newData)
      
      let filteredData = state.filteredDeviceData
      let metrics = NetworkMetrics(from: filteredData)
      
      return .merge(
        .send(._internal(.metricsCalculated(metrics))),
        .send(._internal(.trendDataUpdated(generateTrendData(from: filteredData))))
      )
      
    case .metricsCalculated(let metrics):
      state.currentMetrics = metrics
      return .send(.delegate(.metricsUpdated(metrics)))
      
    case .trendDataUpdated(let trendData):
      state.trendData = trendData
      return .none
      
    case .autoRefreshTick:
      return .send(.view(.refreshData))
    }
  }
  
  private func mergeDeviceData(existing: [DeviceSpeedData], new: [DeviceSpeedData]) -> [DeviceSpeedData] {
    let maxDataPoints = 500
    let combined = existing + new
    let sorted = combined.sorted { $0.timestamp > $1.timestamp }
    return Array(sorted.prefix(maxDataPoints))
  }
  
  private func generateMockDeviceData() -> [DeviceSpeedData] {
    let devices = [
      ("device_001", "iPhone 15 Pro"),
      ("device_002", "iPad Pro"),
      ("device_003", "MacBook Air"),
      ("device_004", "Apple Watch")
    ]
    
    let timestamp = Date()
    
    return devices.map { (deviceId, deviceName) in
      DeviceSpeedData(
        deviceId: deviceId,
        deviceName: deviceName,
        uploadSpeed: Double.random(in: 10...100),
        downloadSpeed: Double.random(in: 20...150),
        timestamp: timestamp,
        connectionQuality: Double.random(in: 0.5...1.0),
        latency: Int.random(in: 20...120),
        signalStrength: Int.random(in: -80...(-30))
      )
    }
  }
  
  private func generateTrendData(from deviceData: [DeviceSpeedData]) -> [TrendDataPoint] {
    let grouped = Dictionary(grouping: deviceData) { data in
      Calendar.current.dateInterval(of: .minute, for: data.timestamp)?.start ?? data.timestamp
    }
    
    return grouped.compactMap { (timestamp, dataPoints) in
      let averageQuality = dataPoints.map(\.connectionQuality).reduce(0, +) / Double(dataPoints.count)
      return TrendDataPoint(timestamp: timestamp, value: averageQuality)
    }
    .sorted { $0.timestamp < $1.timestamp }
    .suffix(20)
    .map { $0 }
  }
}