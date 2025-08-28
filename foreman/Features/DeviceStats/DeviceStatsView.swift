//
//  DeviceStatsView.swift
//  foreman
//
//  Created by Claude on 2025/8/28.
//

import ComposableArchitecture
import OSLog
import SwiftUI

@ViewAction(for: DeviceStatsFeature.self)
struct DeviceStatsView: View {
  @Bindable var store: StoreOf<DeviceStatsFeature>
  private let logger = Logger(subsystem: "foreman", category: "DeviceStatsView")
  
  @State private var showControlPanel = false
  
  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 16) {
          headerView
          
          NetworkSummaryCards(
            metrics: store.currentMetrics,
            trendData: store.trendData
          )
          
          DeviceSpeedChartView(
            deviceData: store.deviceData,
            timeRange: store.timeRange,
            selectedDevices: Set(store.deviceData.map(\.deviceId))
          )
          
          DeviceListView(
            devices: store.deviceData,
            selectedDevices: Set(store.deviceData.map(\.deviceId)),
            onDeviceToggle: { _ in },
            onDeviceDetails: { _ in }
          )
        }
        .padding()
      }
      .navigationTitle("設備網絡統計")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Menu {
            controlPanelMenu
          } label: {
            Image(systemName: "slider.horizontal.3")
              .foregroundColor(.blue)
          }
        }
      }
      .task {
        send(.task)
      }
      .onDisappear {
        send(.teardown)
      }
    }
    .navigationViewStyle(.stack)
  }
  
  @ViewBuilder
  private var headerView: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text("實時監控")
          .font(.title2)
          .fontWeight(.bold)
        
        HStack(spacing: 8) {
          Text("最後更新：")
            .font(.caption)
            .foregroundColor(.secondary)
          
          Text(store.lastRefreshTime, style: .time)
            .font(.caption)
            .fontWeight(.medium)
          
          if store.isAutoRefreshEnabled {
            HStack(spacing: 4) {
              Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
                .scaleEffect(1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: store.lastRefreshTime)
              
              Text("自動刷新")
                .font(.caption)
                .foregroundColor(.green)
            }
          }
        }
      }
      
      Spacer()
      
      Button(action: {
        send(.refreshData)
      }) {
        Image(systemName: "arrow.clockwise")
          .font(.title3)
          .foregroundColor(.blue)
      }
      .disabled(store.isAutoRefreshEnabled)
    }
  }
  
  @ViewBuilder
  private var controlPanelMenu: some View {
    Section("時間範圍") {
      ForEach(DeviceSpeedChartView.TimeRange.allCases, id: \.self) { range in
        Button(action: {
          send(.changeTimeRange(range))
        }) {
          Label {
            Text(range.displayName)
          } icon: {
            if store.timeRange == range {
              Image(systemName: "checkmark")
            }
          }
        }
      }
    }
    
    Divider()
    
    Section("刷新設置") {
      Button(action: {
        send(.toggleAutoRefresh)
      }) {
        Label {
          Text("自動刷新")
        } icon: {
          Image(systemName: store.isAutoRefreshEnabled ? "checkmark.square" : "square")
        }
      }
      
      Button(action: {
        send(.refreshData)
      }) {
        Label("手動刷新", systemImage: "arrow.clockwise")
      }
      .disabled(store.isAutoRefreshEnabled)
    }
  }
}


#Preview {
  DeviceStatsView(
    store: .init(
      initialState: DeviceStatsFeature.State(
        deviceData: mockPreviewData,
        currentMetrics: NetworkMetrics(from: mockPreviewData)
      ),
      reducer: {
        DeviceStatsFeature()
      }
    )
  )
}

private let mockPreviewData: [DeviceSpeedData] = {
  let deviceIds = ["device_001", "device_002", "device_003"]
  let deviceNames = ["iPhone 15 Pro", "iPad Pro", "MacBook Air"]
  
  return (0..<30).compactMap { i in
    let deviceIndex = i % deviceIds.count
    return DeviceSpeedData(
      deviceId: deviceIds[deviceIndex],
      deviceName: deviceNames[deviceIndex],
      uploadSpeed: Double.random(in: 10...80),
      downloadSpeed: Double.random(in: 20...120),
      timestamp: Date().addingTimeInterval(-Double(i * 10)),
      connectionQuality: Double.random(in: 0.6...1.0),
      latency: Int.random(in: 20...100),
      signalStrength: Int.random(in: -70...(-30))
    )
  }
}()
