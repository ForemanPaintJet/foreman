//
//  IfstatFeatureTests.swift
//  foremanTests
//
//  Created by Claude on 2025/8/28.
//

import ComposableArchitecture
import XCTest

@testable import foreman

@MainActor
final class IfstatFeatureTests: XCTestCase {
  func testInitialState() async {
    let store = TestStore(
      initialState: IfstatFeature.State(),
      reducer: { IfstatFeature() }
    )
    
    expectNoDifference(store.state.interfaceData, [])
    expectNoDifference(store.state.timeRange, 300) // 5 minutes
    expectNoDifference(store.state.isAutoRefreshEnabled, true)
  }
  
  func testTaskAction() async {
    let store = TestStore(
      initialState: IfstatFeature.State(),
      reducer: { IfstatFeature() }
    )
    
    await store.send(.view(.task))
    
    await store.receive(\.view.refreshData)
    
    await store.receive(\._internal.interfaceDataUpdated) { _ in
      // Interface data will be updated with mock data
    }
    
    await store.receive(\.delegate.dataUpdated)
  }
  
  func testRefreshData() async {
    let store = TestStore(
      initialState: IfstatFeature.State(),
      reducer: { IfstatFeature() }
    )
    
    await store.send(.view(.refreshData)) {
      $0.lastRefreshTime = Date()
    }
    
    await store.receive(\._internal.interfaceDataUpdated) { _ in
      // Interface data will be updated
    }
    
    await store.receive(\.delegate.dataUpdated)
  }
  
  func testChangeTimeRange() async {
    let store = TestStore(
      initialState: IfstatFeature.State(),
      reducer: { IfstatFeature() }
    )
    
    await store.send(.view(.changeTimeRange(900))) {
      $0.timeRange = 900 // 15 minutes
    }
    
    await store.receive(\.view.refreshData)
    
    await store.receive(\._internal.interfaceDataUpdated) { _ in
      // Interface data will be updated
    }
    
    await store.receive(\.delegate.dataUpdated)
  }
  
  func testToggleAutoRefresh() async {
    let store = TestStore(
      initialState: IfstatFeature.State(isAutoRefreshEnabled: true),
      reducer: { IfstatFeature() }
    )
    
    await store.send(.view(.toggleAutoRefresh)) {
      $0.isAutoRefreshEnabled = false
    }
    
    await store.send(.view(.toggleAutoRefresh)) {
      $0.isAutoRefreshEnabled = true
    }
  }
  
  
  func testNetworkInterfaceDataFormatting() {
    let data = NetworkInterfaceData(
      interfaceName: "en0",
      uploadSpeed: 1.5,
      downloadSpeed: 2.5,
      speedUnit: .megabytesPerSecond
    )
    
    let formattedUpload = data.formattedUploadSpeed
    let formattedDownload = data.formattedDownloadSpeed
    
    expectNoDifference(formattedUpload.value, 1.5)
    expectNoDifference(formattedUpload.unit, "MB/s")
    expectNoDifference(formattedDownload.value, 2.5)
    expectNoDifference(formattedDownload.unit, "MB/s")
  }
  
  func testNetworkInterfaceDataAutoScaling() {
    let data = NetworkInterfaceData(
      interfaceName: "eth0",
      uploadSpeed: 2048.0, // 2048 KB/s = 2 MB/s
      downloadSpeed: 1024.0, // 1024 KB/s = 1 MB/s
      speedUnit: .kilobytesPerSecond
    )
    
    let formattedUpload = data.formattedUploadSpeed
    let formattedDownload = data.formattedDownloadSpeed
    
    // Should auto-scale to MB/s
    expectNoDifference(formattedUpload.unit, "MB/s")
    expectNoDifference(formattedDownload.unit, "MB/s")
    
    // Values should be converted appropriately
    let tolerance = 0.01
    XCTAssertEqual(formattedUpload.value, 2.0, accuracy: tolerance)
    XCTAssertEqual(formattedDownload.value, 1.0, accuracy: tolerance)
  }
}