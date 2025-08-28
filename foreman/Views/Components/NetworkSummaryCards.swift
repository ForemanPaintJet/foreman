//
//  NetworkSummaryCards.swift
//  foreman
//
//  Created by Claude on 2025/8/28.
//

import Charts
import SwiftUI

struct NetworkSummaryCards: View {
  let metrics: NetworkMetrics
  let trendData: [TrendDataPoint]
  
  private let columns = [
    GridItem(.flexible()),
    GridItem(.flexible())
  ]
  
  var body: some View {
    LazyVGrid(columns: columns, spacing: 12) {
      DeviceCountCard(count: metrics.totalDevices)
      BandwidthCard(bandwidth: metrics.totalBandwidthUsage)
      LatencyCard(latency: metrics.averageLatency)
      QualityCard(quality: metrics.averageConnectionQuality, trendData: trendData)
    }
  }
}

struct DeviceCountCard: View {
  let count: Int
  
  var body: some View {
    SummaryCard(
      title: "連接設備",
      value: "\(count)",
      unit: "台",
      icon: "antenna.radiowaves.left.and.right",
      color: .blue,
      trend: nil
    )
  }
}

struct BandwidthCard: View {
  let bandwidth: Double
  
  private var displayValue: String {
    if bandwidth >= 1000 {
      return String(format: "%.1f", bandwidth / 1000)
    } else {
      return String(format: "%.1f", bandwidth)
    }
  }
  
  private var displayUnit: String {
    bandwidth >= 1000 ? "Gbps" : "Mbps"
  }
  
  var body: some View {
    SummaryCard(
      title: "總帶寬",
      value: displayValue,
      unit: displayUnit,
      icon: "speedometer",
      color: .green,
      trend: .up
    )
  }
}

struct LatencyCard: View {
  let latency: Double
  
  private var latencyColor: Color {
    switch latency {
    case 0..<30: return .green
    case 30..<60: return .orange
    default: return .red
    }
  }
  
  var body: some View {
    SummaryCard(
      title: "平均延遲",
      value: String(format: "%.0f", latency),
      unit: "ms",
      icon: "timer",
      color: latencyColor,
      trend: latency < 50 ? .down : .up
    )
  }
}

struct QualityCard: View {
  let quality: Double
  let trendData: [TrendDataPoint]
  
  private var qualityColor: Color {
    switch quality {
    case 0.8...1.0: return .green
    case 0.6..<0.8: return .blue
    case 0.4..<0.6: return .orange
    default: return .red
    }
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: "wifi.circle")
          .font(.title2)
          .foregroundColor(qualityColor)
        
        VStack(alignment: .leading, spacing: 2) {
          Text("連接質量")
            .font(.caption)
            .foregroundColor(.secondary)
          
          HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("\(Int(quality * 100))")
              .font(.title2)
              .fontWeight(.bold)
              .foregroundColor(qualityColor)
            Text("%")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        
        Spacer()
      }
      
      if !trendData.isEmpty {
        Chart(trendData) { point in
          LineMark(
            x: .value("Time", point.timestamp),
            y: .value("Quality", point.value)
          )
          .foregroundStyle(qualityColor)
          .lineStyle(StrokeStyle(lineWidth: 2))
          
          AreaMark(
            x: .value("Time", point.timestamp),
            y: .value("Quality", point.value)
          )
          .foregroundStyle(qualityColor.opacity(0.2))
        }
        .frame(height: 30)
        .chartYScale(domain: 0...1)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
      }
    }
    .padding(12)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
  }
}

struct SummaryCard: View {
  let title: String
  let value: String
  let unit: String
  let icon: String
  let color: Color
  let trend: TrendDirection?
  
  enum TrendDirection {
    case up, down
    
    var systemImage: String {
      switch self {
      case .up: return "arrow.up.right"
      case .down: return "arrow.down.right"
      }
    }
    
    var color: Color {
      switch self {
      case .up: return .green
      case .down: return .red
      }
    }
  }
  
  var body: some View {
    HStack {
      Image(systemName: icon)
        .font(.title2)
        .foregroundColor(color)
      
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption)
          .foregroundColor(.secondary)
        
        HStack(alignment: .firstTextBaseline, spacing: 2) {
          Text(value)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.primary)
          Text(unit)
            .font(.caption)
            .foregroundColor(.secondary)
          
          if let trend = trend {
            Image(systemName: trend.systemImage)
              .font(.caption2)
              .foregroundColor(trend.color)
          }
        }
      }
      
      Spacer()
    }
    .padding(12)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
  }
}

struct TrendDataPoint: Identifiable, Equatable {
  let id = UUID()
  let timestamp: Date
  let value: Double
  
  init(timestamp: Date, value: Double) {
    self.timestamp = timestamp
    self.value = value
  }
}

#Preview {
  ScrollView {
    VStack(spacing: 16) {
      NetworkSummaryCards(
        metrics: NetworkMetrics(
          totalDevices: 8,
          averageUploadSpeed: 42.5,
          averageDownloadSpeed: 85.2,
          peakUploadSpeed: 95.8,
          peakDownloadSpeed: 145.6,
          totalBandwidthUsage: 1024.7,
          averageLatency: 35.2,
          averageConnectionQuality: 0.84
        ),
        trendData: mockTrendData
      )
      
      Spacer(minLength: 100)
    }
    .padding()
  }
  .background(Color(.systemGroupedBackground))
}

private let mockTrendData: [TrendDataPoint] = {
  (0..<20).map { i in
    TrendDataPoint(
      timestamp: Date().addingTimeInterval(-Double(i * 30)),
      value: 0.7 + Double.random(in: 0...0.3)
    )
  }.reversed()
}()