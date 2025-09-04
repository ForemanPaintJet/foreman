//
//  SimpleDeviceStatsView.swift
//  foreman
//
//  Created by Claude on 2025/8/28.
//

import ComposableArchitecture
import OSLog
import SwiftUI

@ViewAction(for: DeviceStatsFeature.self)
struct SimpleDeviceStatsView: View {
  @Bindable var store: StoreOf<DeviceStatsFeature>
  private let logger = Logger(subsystem: "foreman", category: "SimpleDeviceStatsView")
  
  private let columns = [
    GridItem(.flexible(), spacing: 16),
    GridItem(.flexible(), spacing: 16)
  ]
  
  private var groupedDeviceData: [String: [DeviceSpeedData]] {
    Dictionary(grouping: store.deviceData, by: \.deviceId)
  }
  
  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 20) {
          headerView
          
          if groupedDeviceData.isEmpty {
            emptyStateView
          } else {
            deviceCardsGrid
          }
        }
        .padding()
      }
      .navigationTitle("設備網絡監控")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          timeRangeMenu
        }
      }
      .refreshable {
        send(.refreshData)
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
    VStack(spacing: 8) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("實時監控")
            .font(.title2)
            .fontWeight(.bold)
          
          Text("連接設備：\(groupedDeviceData.count) 台")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        
        Spacer()
        
        VStack(alignment: .trailing, spacing: 4) {
          autoRefreshIndicator
          
          Text("最後更新：\(store.lastRefreshTime.formatted(date: .omitted, time: .shortened))")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      
      Divider()
        .padding(.horizontal, -16)
    }
  }
  
  @ViewBuilder
  private var autoRefreshIndicator: some View {
    if store.isAutoRefreshEnabled {
      HStack(spacing: 6) {
        Circle()
          .fill(.green)
          .frame(width: 8, height: 8)
          .scaleEffect(1.0)
          .animation(
            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
            value: store.lastRefreshTime
          )
        
        Text("自動刷新")
          .font(.caption)
          .foregroundColor(.green)
      }
    } else {
      HStack(spacing: 6) {
        Circle()
          .fill(.gray)
          .frame(width: 8, height: 8)
        
        Text("手動刷新")
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
  }
  
  @ViewBuilder
  private var deviceCardsGrid: some View {
    LazyVGrid(columns: columns, spacing: 16) {
      ForEach(Array(groupedDeviceData.keys.sorted()), id: \.self) { deviceId in
        if let deviceData = groupedDeviceData[deviceId] {
          SingleDeviceChartCard(
            deviceData: deviceData,
            timeRange: store.timeRange
          )
          .transition(.scale.combined(with: .opacity))
        }
      }
    }
    .animation(.easeInOut(duration: 0.3), value: groupedDeviceData.count)
  }
  
  @ViewBuilder
  private var emptyStateView: some View {
    VStack(spacing: 24) {
      Image(systemName: "antenna.radiowaves.left.and.right.slash")
        .font(.system(size: 60))
        .foregroundColor(.secondary)
      
      VStack(spacing: 8) {
        Text("無連接設備")
          .font(.title2)
          .fontWeight(.medium)
        
        Text("等待設備連接到服務器...")
          .font(.subheadline)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      }
      
      Button("手動刷新") {
        send(.refreshData)
      }
      .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 300)
  }
  
  @ViewBuilder
  private var timeRangeMenu: some View {
    Menu {
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
        
        if !store.isAutoRefreshEnabled {
          Button(action: {
            send(.refreshData)
          }) {
            Label("手動刷新", systemImage: "arrow.clockwise")
          }
        }
      }
    } label: {
      Image(systemName: "ellipsis.circle")
        .foregroundColor(.blue)
    }
  }
}

#Preview {
  SimpleDeviceStatsView(
    store: .init(
      initialState: DeviceStatsFeature.State(
        deviceData: mockSimplePreviewData,
        currentMetrics: NetworkMetrics(from: mockSimplePreviewData)
      ),
      reducer: {
        DeviceStatsFeature()
      }
    )
  )
}

private let mockSimplePreviewData: [DeviceSpeedData] = {
  let deviceConfigs = [
    ("device_001", "iPhone 15 Pro"),
    ("device_002", "iPad Pro"),
    ("device_003", "MacBook Air"),
    ("device_004", "Apple Watch")
  ]
  
  return deviceConfigs.flatMap { (deviceId, deviceName) in
    (0..<10).map { i in
      DeviceSpeedData(
        deviceId: deviceId,
        deviceName: deviceName,
        uploadSpeed: Double.random(in: 10...100),
        downloadSpeed: Double.random(in: 20...150),
        timestamp: Date().addingTimeInterval(-Double(i * 30)),
        connectionQuality: Double.random(in: 0.6...1.0),
        latency: Int.random(in: 20...120),
        signalStrength: Int.random(in: -80...(-30))
      )
    }
  }
}()