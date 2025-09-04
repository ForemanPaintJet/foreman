//
//  DeviceSpeedChartView.swift
//  foreman
//
//  Created by Claude on 2025/8/28.
//

import Charts
import SwiftUI

struct DeviceSpeedChartView: View {
  let deviceData: [DeviceSpeedData]
  let timeRange: TimeRange
  let selectedDevices: Set<String>
  
  @State private var showUpload = true
  @State private var showDownload = true
  
  enum TimeRange: String, CaseIterable {
    case oneMinute = "1m"
    case fiveMinutes = "5m"
    case fifteenMinutes = "15m"
    
    var duration: TimeInterval {
      switch self {
      case .oneMinute: return 60
      case .fiveMinutes: return 300
      case .fifteenMinutes: return 900
      }
    }
    
    var displayName: String {
      switch self {
      case .oneMinute: return "1 分鐘"
      case .fiveMinutes: return "5 分鐘"
      case .fifteenMinutes: return "15 分鐘"
      }
    }
  }
  
  private var filteredData: [ChartDataPoint] {
    let cutoffTime = Date().addingTimeInterval(-timeRange.duration)
    let recentData = deviceData.filter { $0.timestamp >= cutoffTime }
    
    var points: [ChartDataPoint] = []
    
    for data in recentData where selectedDevices.contains(data.deviceId) {
      if showUpload {
        points.append(ChartDataPoint(
          deviceId: data.deviceId,
          speed: data.uploadSpeed,
          type: .upload,
          timestamp: data.timestamp
        ))
      }
      if showDownload {
        points.append(ChartDataPoint(
          deviceId: data.deviceId,
          speed: data.downloadSpeed,
          type: .download,
          timestamp: data.timestamp
        ))
      }
    }
    
    return points.sorted { $0.timestamp < $1.timestamp }
  }
  
  private var maxSpeed: Double {
    filteredData.map(\.speed).max() ?? 100
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      headerView
      
      if filteredData.isEmpty {
        emptyStateView
      } else {
        chartView
      }
      
      legendView
    }
    .padding()
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
  }
  
  @ViewBuilder
  private var headerView: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text("設備網絡速率")
          .font(.headline)
          .fontWeight(.semibold)
        
        Text("\(timeRange.displayName) • \(selectedDevices.count) 設備")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      
      Spacer()
      
      HStack(spacing: 16) {
        Toggle("上傳", isOn: $showUpload)
          .toggleStyle(.button)
          .buttonStyle(.bordered)
          .controlSize(.small)
        
        Toggle("下載", isOn: $showDownload)
          .toggleStyle(.button)
          .buttonStyle(.bordered)
          .controlSize(.small)
      }
    }
  }
  
  @ViewBuilder
  private var chartView: some View {
    Chart(filteredData) { point in
      LineMark(
        x: .value("時間", point.timestamp),
        y: .value("速率", point.speed)
      )
      .foregroundStyle(by: .value("設備", point.deviceId))
      .symbol(by: .value("類型", point.type.rawValue))
      .lineStyle(StrokeStyle(lineWidth: 2))
      .interpolationMethod(.catmullRom)
      
      AreaMark(
        x: .value("時間", point.timestamp),
        y: .value("速率", point.speed)
      )
      .foregroundStyle(
        by: .value("設備", point.deviceId)
      )
      .opacity(0.1)
    }
    .frame(height: 200)
    .chartYScale(domain: 0...max(maxSpeed * 1.1, 10))
    .chartXAxis {
      AxisMarks(values: .stride(by: timeRange.duration / 4)) { _ in
        AxisGridLine()
        AxisTick()
        AxisValueLabel(format: .dateTime.hour().minute())
      }
    }
    .chartYAxis {
      AxisMarks { _ in
        AxisGridLine()
        AxisTick()
        AxisValueLabel()
      }
    }
    .chartYAxisLabel("速率 (Mbps)", alignment: .leading)
    .chartXAxisLabel("時間", alignment: .center)
    .chartLegend(position: .bottom, alignment: .center)
    .animation(.easeInOut(duration: 0.5), value: filteredData.count)
  }
  
  @ViewBuilder
  private var emptyStateView: some View {
    VStack(spacing: 16) {
      Image(systemName: "chart.line.uptrend.xyaxis")
        .font(.system(size: 40))
        .foregroundColor(.secondary)
      
      Text("無數據顯示")
        .font(.title3)
        .fontWeight(.medium)
      
      Text("選擇設備或調整時間範圍以查看網絡速率")
        .font(.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(height: 200)
    .frame(maxWidth: .infinity)
  }
  
  @ViewBuilder
  private var legendView: some View {
    HStack(spacing: 20) {
      HStack(spacing: 8) {
        Circle()
          .fill(.blue)
          .frame(width: 8, height: 8)
        Text("上傳")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      
      HStack(spacing: 8) {
        Circle()
          .fill(.green)
          .frame(width: 8, height: 8)
        Text("下載")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      
      Spacer()
      
      Text("最大: \(maxSpeed, specifier: "%.1f") Mbps")
        .font(.caption)
        .foregroundColor(.secondary)
    }
  }
}

#Preview {
  DeviceSpeedChartView(
    deviceData: mockDeviceData,
    timeRange: .fiveMinutes,
    selectedDevices: Set(mockDeviceData.map(\.deviceId))
  )
}

private let mockDeviceData: [DeviceSpeedData] = {
  let deviceIds = ["device_001", "device_002", "device_003"]
  let deviceNames = ["iPhone 15", "iPad Pro", "MacBook Air"]
  
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