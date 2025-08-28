//
//  DeviceStatsFeatureTests.swift
//  foremanTests
//
//  Created by Claude on 2025/8/28.
//

import ComposableArchitecture
import XCTest

@testable import foreman

@MainActor
final class DeviceStatsFeatureTests: XCTestCase {
  func testInitialState() async {
    let store = TestStore(
      initialState: DeviceStatsFeature.State(),
      reducer: { DeviceStatsFeature() }
    )
    
    expectNoDifference(store.state.deviceData, [])
    expectNoDifference(store.state.selectedDevices, Set<String>())
    expectNoDifference(store.state.timeRange, .fiveMinutes)
    expectNoDifference(store.state.currentMetrics, .empty)
    expectNoDifference(store.state.isAutoRefreshEnabled, true)
  }
  
  func testTaskAction() async {
    let store = TestStore(
      initialState: DeviceStatsFeature.State(),
      reducer: { DeviceStatsFeature() }
    )
    
    await store.send(.view(.task)) {
      // Available devices should be empty initially, so selectedDevices remains empty
      $0.selectedDevices = Set([])
    }
    
    await store.receive(\.view.refreshData)
    
    await store.receive(\._internal.deviceDataUpdated) { _ in
      // Device data will be updated with mock data
    }
    
    await store.receive(\._internal.metricsCalculated) { _ in
      // Metrics will be calculated
    }
    
    await store.receive(\._internal.trendDataUpdated) { _ in
      // Trend data will be updated
    }
    
    await store.receive(\.delegate.metricsUpdated)
  }
  
  func testToggleDevice() async {
    let store = TestStore(
      initialState: DeviceStatsFeature.State(),
      reducer: { DeviceStatsFeature() }
    )
    
    let deviceId = "device_001"
    
    await store.send(.view(.toggleDevice(deviceId))) {
      $0.selectedDevices.insert(deviceId)
    }
    
    await store.receive(\.delegate.deviceSelectionChanged) { _ in
      // Delegate will be notified
    }
    
    await store.send(.view(.toggleDevice(deviceId))) {
      $0.selectedDevices.remove(deviceId)
    }
    
    await store.receive(\.delegate.deviceSelectionChanged) { _ in
      // Delegate will be notified
    }
  }
  
  func testSelectAllDevices() async {
    let mockData = [
      DeviceSpeedData(
        deviceId: "device_001",
        deviceName: "iPhone",
        uploadSpeed: 50,
        downloadSpeed: 100
      ),
      DeviceSpeedData(
        deviceId: "device_002", 
        deviceName: "iPad",
        uploadSpeed: 30,
        downloadSpeed: 80
      )
    ]
    
    let store = TestStore(
      initialState: DeviceStatsFeature.State(deviceData: mockData),
      reducer: { DeviceStatsFeature() }
    )
    
    await store.send(.view(.selectAllDevices)) {
      $0.selectedDevices = Set(["device_001", "device_002"])
    }
    
    await store.receive(\.delegate.deviceSelectionChanged) { _ in
      // Delegate will be notified
    }
  }
  
  func testDeselectAllDevices() async {
    let store = TestStore(
      initialState: DeviceStatsFeature.State(
        selectedDevices: Set(["device_001", "device_002"])
      ),
      reducer: { DeviceStatsFeature() }
    )
    
    await store.send(.view(.deselectAllDevices)) {
      $0.selectedDevices.removeAll()
    }
    
    await store.receive(\.delegate.deviceSelectionChanged) { _ in
      // Delegate will be notified
    }
  }
  
  func testChangeTimeRange() async {
    let store = TestStore(
      initialState: DeviceStatsFeature.State(),
      reducer: { DeviceStatsFeature() }
    )
    
    await store.send(.view(.changeTimeRange(.oneMinute))) {
      $0.timeRange = .oneMinute
    }
    
    await store.receive(\.view.refreshData)
    
    await store.receive(\._internal.deviceDataUpdated) { _ in
      // Device data will be updated
    }
    
    await store.receive(\._internal.metricsCalculated) { _ in
      // Metrics will be calculated
    }
    
    await store.receive(\._internal.trendDataUpdated) { _ in
      // Trend data will be updated  
    }
    
    await store.receive(\.delegate.metricsUpdated)
  }
  
  func testToggleAutoRefresh() async {
    let store = TestStore(
      initialState: DeviceStatsFeature.State(isAutoRefreshEnabled: true),
      reducer: { DeviceStatsFeature() }
    )
    
    await store.send(.view(.toggleAutoRefresh)) {
      $0.isAutoRefreshEnabled = false
    }
    
    await store.send(.view(.toggleAutoRefresh)) {
      $0.isAutoRefreshEnabled = true
    }
  }
  
  func testShowAndHideDeviceDetails() async {
    let store = TestStore(
      initialState: DeviceStatsFeature.State(),
      reducer: { DeviceStatsFeature() }
    )
    
    let deviceId = "device_001"
    
    await store.send(.view(.showDeviceDetails(deviceId))) {
      $0.showDeviceDetails = deviceId
    }
    
    await store.send(.view(.hideDeviceDetails)) {
      $0.showDeviceDetails = nil
    }
  }
  
  func testNetworkMetricsCalculation() {
    let deviceData = [
      DeviceSpeedData(
        deviceId: "device_001",
        deviceName: "iPhone",
        uploadSpeed: 50,
        downloadSpeed: 100,
        connectionQuality: 0.9,
        latency: 30
      ),
      DeviceSpeedData(
        deviceId: "device_002",
        deviceName: "iPad", 
        uploadSpeed: 30,
        downloadSpeed: 80,
        connectionQuality: 0.8,
        latency: 40
      )
    ]
    
    let metrics = NetworkMetrics(from: deviceData)
    
    expectNoDifference(metrics.totalDevices, 2)
    expectNoDifference(metrics.averageUploadSpeed, 40.0)
    expectNoDifference(metrics.averageDownloadSpeed, 90.0)
    expectNoDifference(metrics.peakUploadSpeed, 50.0)
    expectNoDifference(metrics.peakDownloadSpeed, 100.0)
    expectNoDifference(metrics.totalBandwidthUsage, 260.0)
    expectNoDifference(metrics.averageLatency, 35.0)
    expectNoDifference(metrics.averageConnectionQuality, 0.85)
  }
}