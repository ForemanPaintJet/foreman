//
//  SimpleInterfaceCard.swift
//  foreman
//
//  Created by Claude on 2025/8/28.
//

import Charts
import SwiftUI

struct SimpleInterfaceCard: View {
  let interfaceData: [NetworkInterfaceData]
  let timeRange: TimeInterval
  
  private var latestData: NetworkInterfaceData? {
    interfaceData.max { $0.timestamp < $1.timestamp }
  }
  
  private var recentData: [NetworkInterfaceData] {
    let cutoffTime = Date().addingTimeInterval(-timeRange)
    return interfaceData
      .filter { $0.timestamp >= cutoffTime }
      .sorted { $0.timestamp < $1.timestamp }
      .suffix(20) // Keep last 20 data points for chart
      .map { $0 }
  }
  
  private var maxSpeed: Double {
    let speeds = recentData.flatMap { [$0.uploadSpeedInBytes, $0.downloadSpeedInBytes] }
    return speeds.max() ?? 1024 // Default 1KB minimum
  }
  
  var body: some View {
    if let latest = latestData {
      VStack(spacing: 12) {
        headerSection(latest)
        speedDisplaySection(latest)
        chartSection
      }
      .padding(16)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
      .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
    } else {
      EmptyView()
    }
  }
  
  @ViewBuilder
  private func headerSection(_ data: NetworkInterfaceData) -> some View {
    HStack {
      interfaceIcon(data.interfaceName)
        .font(.title3)
        .foregroundColor(.blue)
      
      VStack(alignment: .leading, spacing: 2) {
        Text(data.interfaceName)
          .font(.subheadline)
          .fontWeight(.semibold)
          .foregroundColor(.primary)
        
        Text(formatTimestamp(data.timestamp))
          .font(.caption2)
          .foregroundColor(.secondary)
      }
      
      Spacer()
      
      statusIndicator
    }
  }
  
  @ViewBuilder
  private func speedDisplaySection(_ data: NetworkInterfaceData) -> some View {
    HStack(spacing: 0) {
      speedColumn(
        title: "上傳",
        value: data.formattedUploadSpeed.value,
        unit: data.formattedUploadSpeed.unit,
        color: .blue
      )
      
      Spacer()
      
      speedColumn(
        title: "下載",
        value: data.formattedDownloadSpeed.value,
        unit: data.formattedDownloadSpeed.unit,
        color: .green
      )
    }
  }
  
  @ViewBuilder
  private func speedColumn(title: String, value: Double, unit: String, color: Color) -> some View {
    VStack(alignment: .center, spacing: 4) {
      Text(title)
        .font(.caption2)
        .foregroundColor(.secondary)
      
      HStack(alignment: .firstTextBaseline, spacing: 2) {
        Text(String(format: "%.1f", value))
          .font(.title2)
          .fontWeight(.bold)
          .foregroundColor(color)
        
        Text(unit)
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
  }
  
  @ViewBuilder
  private var chartSection: some View {
    if !recentData.isEmpty {
      Chart {
        ForEach(recentData) { data in
          LineMark(
            x: .value("時間", data.timestamp),
            y: .value("上傳", data.uploadSpeedInBytes)
          )
          .foregroundStyle(.blue)
          .lineStyle(StrokeStyle(lineWidth: 1.5))
          .interpolationMethod(.catmullRom)
          
          LineMark(
            x: .value("時間", data.timestamp),
            y: .value("下載", data.downloadSpeedInBytes)
          )
          .foregroundStyle(.green)
          .lineStyle(StrokeStyle(lineWidth: 1.5))
          .interpolationMethod(.catmullRom)
        }
      }
      .frame(height: 50)
      .chartYScale(domain: 0...max(maxSpeed * 1.1, 1024))
      .animation(.easeInOut(duration: 0.3), value: recentData.count)
    } else {
      Rectangle()
        .fill(.quaternary)
        .frame(height: 50)
        .overlay(
          Text("無數據")
            .font(.caption2)
            .foregroundColor(.orange)
        )
    }
  }
  
  @ViewBuilder
  private var statusIndicator: some View {
    let hasRecentData = latestData?.timestamp.timeIntervalSinceNow ?? -Double.infinity > -30
    
    Circle()
      .fill(hasRecentData ? .green : .gray)
      .frame(width: 8, height: 8)
      .scaleEffect(hasRecentData ? 1.2 : 1.0)
      .animation(
        hasRecentData ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .default,
        value: hasRecentData
      )
  }
  
  @ViewBuilder
  private func interfaceIcon(_ interfaceName: String) -> some View {
    let lowercased = interfaceName.lowercased()
    let iconName: String
    
    Image(systemName: "wifi")
  }
  
  private func formatTimestamp(_ timestamp: Date) -> String {
    let interval = Date().timeIntervalSince(timestamp)
    
    if interval < 60 {
      return "\(Int(interval))秒前"
    } else if interval < 3600 {
      return "\(Int(interval / 60))分前"
    } else {
      return timestamp.formatted(date: .omitted, time: .shortened)
    }
  }
}

#Preview {
  let mockData = (0..<10).map { i in
    NetworkInterfaceData(
      interfaceName: "en0",
      uploadSpeed: Double.random(in: 50...500),
      downloadSpeed: Double.random(in: 100...1000),
      speedUnit: .kilobytesPerSecond,
      timestamp: Date().addingTimeInterval(-Double(i * 30))
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
      SimpleInterfaceCard(
        interfaceData: mockData,
        timeRange: 300 // 5 minutes
      )
      
      SimpleInterfaceCard(
        interfaceData: (0..<8).map { i in
          NetworkInterfaceData(
            interfaceName: "wlan0",
            uploadSpeed: Double.random(in: 20...200),
            downloadSpeed: Double.random(in: 80...800),
            speedUnit: .kilobytesPerSecond,
            timestamp: Date().addingTimeInterval(-Double(i * 30))
          )
        },
        timeRange: 300
      )
      
      SimpleInterfaceCard(
        interfaceData: (0..<12).map { i in
          NetworkInterfaceData(
            interfaceName: "eth0",
            uploadSpeed: Double.random(in: 1...50),
            downloadSpeed: Double.random(in: 5...200),
            speedUnit: .megabytesPerSecond,
            timestamp: Date().addingTimeInterval(-Double(i * 15))
          )
        },
        timeRange: 300
      )
    }
    .padding()
  }
  .background(Color(.systemGroupedBackground))
}
