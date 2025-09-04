//
//  SingleDeviceChartCard.swift
//  foreman
//
//  Created by Claude on 2025/8/28.
//

import Charts
import SwiftUI

struct SingleDeviceChartCard: View {
  let deviceData: [DeviceSpeedData]
  let timeRange: DeviceSpeedChartView.TimeRange
  
  private var deviceInfo: DeviceSpeedData? {
    deviceData.max { $0.timestamp < $1.timestamp }
  }
  
  private var recentData: [DeviceSpeedData] {
    let cutoffTime = Date().addingTimeInterval(-timeRange.duration)
    return deviceData
      .filter { $0.timestamp >= cutoffTime }
      .sorted { $0.timestamp < $1.timestamp }
      .suffix(10)
      .map { $0 }
  }
  
  private var maxSpeed: Double {
    let speeds = recentData.flatMap { [$0.uploadSpeed, $0.downloadSpeed] }
    return speeds.max() ?? 100
  }
  
  var body: some View {
    if let device = deviceInfo {
      VStack(spacing: 12) {
        headerSection(device)
        speedDisplaySection(device)
        chartSection
        statusSection(device)
      }
      .padding()
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
      .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    } else {
      EmptyView()
    }
  }
  
  @ViewBuilder
  private func headerSection(_ device: DeviceSpeedData) -> some View {
    HStack {
      deviceIcon(device.deviceName)
        .font(.title2)
        .foregroundColor(.blue)
      
      VStack(alignment: .leading, spacing: 2) {
        Text(device.deviceName)
          .font(.subheadline)
          .fontWeight(.semibold)
          .lineLimit(1)
        
        Text(device.deviceId)
          .font(.caption2)
          .foregroundColor(.secondary)
          .lineLimit(1)
      }
      
      Spacer()
      
      connectionQualityBadge(device.connectionQuality)
    }
  }
  
  @ViewBuilder
  private func speedDisplaySection(_ device: DeviceSpeedData) -> some View {
    HStack(spacing: 20) {
      VStack(alignment: .center, spacing: 4) {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
          Image(systemName: "arrow.up")
            .font(.caption2)
            .foregroundColor(.blue)
          Text("\(device.uploadSpeed, specifier: "%.1f")")
            .font(.title3)
            .fontWeight(.bold)
            .foregroundColor(.primary)
        }
        Text("上傳")
          .font(.caption2)
          .foregroundColor(.secondary)
      }
      
      VStack(alignment: .center, spacing: 4) {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
          Image(systemName: "arrow.down")
            .font(.caption2)
            .foregroundColor(.green)
          Text("\(device.downloadSpeed, specifier: "%.1f")")
            .font(.title3)
            .fontWeight(.bold)
            .foregroundColor(.primary)
        }
        Text("下載")
          .font(.caption2)
          .foregroundColor(.secondary)
      }
      
      Spacer()
      
      Text("Mbps")
        .font(.caption)
        .foregroundColor(.secondary)
    }
  }
  
  @ViewBuilder
  private var chartSection: some View {
    if !recentData.isEmpty {
      Chart {
        ForEach(recentData) { data in
          LineMark(
            x: .value("時間", data.timestamp),
            y: .value("上傳", data.uploadSpeed)
          )
          .foregroundStyle(.blue)
          .lineStyle(StrokeStyle(lineWidth: 2))
          .interpolationMethod(.catmullRom)
          
          LineMark(
            x: .value("時間", data.timestamp),
            y: .value("下載", data.downloadSpeed)
          )
          .foregroundStyle(.green)
          .lineStyle(StrokeStyle(lineWidth: 2))
          .interpolationMethod(.catmullRom)
        }
      }
      .frame(height: 60)
      .chartYScale(domain: 0...max(maxSpeed * 1.1, 10))
      .chartXAxis(.hidden)
      .chartYAxis(.hidden)
      .animation(.easeInOut(duration: 0.5), value: recentData.count)
    } else {
      Rectangle()
        .fill(.ultraThinMaterial)
        .frame(height: 60)
        .overlay(
          Text("無數據")
            .font(.caption)
            .foregroundColor(.secondary)
        )
    }
  }
  
  @ViewBuilder
  private func statusSection(_ device: DeviceSpeedData) -> some View {
    HStack {
      HStack(spacing: 4) {
        Image(systemName: wifiIcon(for: device.signalStrength))
          .font(.caption)
          .foregroundColor(signalColor(for: device.signalStrength))
        Text("\(device.signalStrength)dBm")
          .font(.caption2)
          .foregroundColor(.secondary)
      }
      
      Spacer()
      
      HStack(spacing: 4) {
        Image(systemName: "timer")
          .font(.caption)
          .foregroundColor(.orange)
        Text("\(device.latency)ms")
          .font(.caption2)
          .foregroundColor(.secondary)
      }
    }
  }
  
  @ViewBuilder
  private func deviceIcon(_ deviceName: String) -> some View {
    let lowercased = deviceName.lowercased()
    let iconName: String
    Image(systemName: "iphone")
  }
  
  @ViewBuilder
  private func connectionQualityBadge(_ quality: Double) -> some View {
    let qualityText = "\(Int(quality * 100))%"
    let qualityColor = connectionQualityColor(quality)
    
    Text(qualityText)
      .font(.caption)
      .fontWeight(.medium)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(qualityColor.opacity(0.2), in: Capsule())
      .foregroundColor(qualityColor)
  }
  
  private func connectionQualityColor(_ quality: Double) -> Color {
    switch quality {
    case 0.8...1.0: return .green
    case 0.6..<0.8: return .blue
    case 0.4..<0.6: return .orange
    default: return .red
    }
  }
  
  private func signalColor(for strength: Int) -> Color {
    switch strength {
    case -30...0: return .green
    case -50...(-31): return .blue
    case -70...(-51): return .orange
    default: return .red
    }
  }
  
  private func wifiIcon(for strength: Int) -> String {
    switch strength {
    case -30...0: return "wifi"
    case -50...(-31): return "wifi"
    case -70...(-51): return "wifi"
    default: return "wifi.slash"
    }
  }
}

#Preview {
  let mockData = Array(0..<8).map { i in
    DeviceSpeedData(
      deviceId: "device_001",
      deviceName: "iPhone 15 Pro",
      uploadSpeed: Double.random(in: 20...80),
      downloadSpeed: Double.random(in: 40...120),
      timestamp: Date().addingTimeInterval(-Double(i * 30)),
      connectionQuality: Double.random(in: 0.7...1.0),
      latency: Int.random(in: 20...60),
      signalStrength: Int.random(in: -60...(-30))
    )
  }
  
  return ScrollView {
    LazyVGrid(
      columns: [
        GridItem(.flexible()),
        GridItem(.flexible())
      ],
      spacing: 16
    ) {
      SingleDeviceChartCard(
        deviceData: mockData,
        timeRange: .fiveMinutes
      )
      
      SingleDeviceChartCard(
        deviceData: mockData.map { data in
          DeviceSpeedData(
            deviceId: "device_002",
            deviceName: "iPad Pro",
            uploadSpeed: data.uploadSpeed * 0.8,
            downloadSpeed: data.downloadSpeed * 1.2,
            timestamp: data.timestamp,
            connectionQuality: data.connectionQuality * 0.9,
            latency: data.latency + 10,
            signalStrength: data.signalStrength - 5
          )
        },
        timeRange: .fiveMinutes
      )
      
      SingleDeviceChartCard(
        deviceData: mockData.map { data in
          DeviceSpeedData(
            deviceId: "device_003",
            deviceName: "MacBook Air",
            uploadSpeed: data.uploadSpeed * 1.2,
            downloadSpeed: data.downloadSpeed * 0.9,
            timestamp: data.timestamp,
            connectionQuality: data.connectionQuality * 0.85,
            latency: data.latency + 5,
            signalStrength: data.signalStrength - 10
          )
        },
        timeRange: .fiveMinutes
      )
    }
    .padding()
  }
  .background(Color(.systemGroupedBackground))
}
