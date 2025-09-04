//
//  IfstatView.swift
//  foreman
//
//  Created by Claude on 2025/8/28.
//

import Charts
import ComposableArchitecture
import MQTTNIO
import NIOCore
import OSLog
import SwiftUI

@ViewAction(for: IfstatFeature.self)
struct IfstatView: View {
  @Bindable var store: StoreOf<IfstatFeature>
  private let logger = Logger(subsystem: "foreman", category: "IfstatView")
  
  private var hasData: Bool {
    !store.interfaceData.isEmpty
  }
  
  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 20) {
          if let error = store.lastError {
            errorBanner(error: error)
          }
          
          headerView
          
          if hasData {
            dataVisualizationCard
          } else {
            emptyStateView
          }
        }
        .padding()
      }
      .navigationTitle("\(store.topicName) Monitoring")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          controlMenu
        }
      }
    }
    .navigationViewStyle(.stack)
    .task {
      send(.task)
    }
    .onDisappear {
      send(.teardown)
    }
  }
  
  @ViewBuilder
  private var headerView: some View {
    VStack(spacing: 8) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("MQTT Data Monitoring")
            .font(.title2)
            .fontWeight(.bold)
          
          Text("Topic: \(store.topicName)")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        
        Spacer()
        
        VStack(alignment: .trailing, spacing: 4) {
          dataSourceIndicator
          
          Text("Updated: \(formatRelativeTime(store.lastRefreshTime))")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      
      Divider()
        .padding(.horizontal, -16)
    }
  }
  
  @ViewBuilder
  private var dataSourceIndicator: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(.blue)
        .frame(width: 8, height: 8)
        .scaleEffect(1.0)
        .animation(
          .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
          value: hasData
        )
      
      Text("Real-time Data")
        .font(.caption)
        .foregroundColor(.blue)
    }
  }
  
  @ViewBuilder
  private var chartHeaderView: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 4) {
        Text(sensorDisplayName)
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(.primary)
        
        Text("Network Interface Monitoring")
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
      
      Spacer()
      
      if let latestData = store.latestData {
        VStack(alignment: .trailing, spacing: 4) {
          HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(latestData.value)")
              .font(.title.bold())
              .foregroundColor(.primary)
            
            Text(sensorUnit)
              .font(.caption)
              .foregroundColor(.secondary)
          }
          
          Text("\(latestData.timestamp, format: .dateTime.hour().minute().second())")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
    }
  }
  
  private var sensorDisplayName: String {
    if let displayName = store.displayName {
      return displayName
    }
    // Extract a friendly name from topic as fallback
    let components = store.topicName.components(separatedBy: "/")
    if components.count >= 2 {
      return components[1].capitalized + " Data"
    }
    return store.topicName
  }
  
  private var sensorUnit: String {
    return store.unit
  }
  
  @ViewBuilder
  private var dataVisualizationCard: some View {
    VStack(spacing: 16) {
      // Chart with integrated header
      VStack(alignment: .leading, spacing: 12) {
        chartHeaderView
        
        Chart(store.interfaceData, id: \.timestamp) { data in
          LineMark(
            x: .value("Time", data.timestamp),
            y: .value("Value", data.value)
          )
          .foregroundStyle(.blue)
          .symbol(.circle)
          .symbolSize(30)
          
          AreaMark(
            x: .value("Time", data.timestamp),
            y: .value("Value", data.value)
          )
          .foregroundStyle(.blue.opacity(0.1))
        }
        .frame(height: 200)
        .chartXAxis {
          AxisMarks(values: .automatic(desiredCount: 5)) { value in
            AxisGridLine()
            AxisValueLabel {
              if let date = value.as(Date.self) {
                Text(date, format: .dateTime.hour().minute())
                  .font(.caption)
              }
            }
          }
        }
        .chartYAxis {
          AxisMarks { value in
            AxisGridLine()
            AxisValueLabel {
              if let intValue = value.as(Int.self) {
                Text("\(intValue)")
                  .font(.caption)
              }
            }
          }
        }
      }
      .padding()
      .background(Color(.systemBackground))
      .cornerRadius(12)
      .shadow(radius: 2)
    }
    .transition(.scale.combined(with: .opacity))
    .animation(.easeInOut(duration: 0.3), value: hasData)
  }
  
  @ViewBuilder
  private var emptyStateView: some View {
    VStack(spacing: 24) {
      Image(systemName: "antenna.radiowaves.left.and.right.slash")
        .font(.system(size: 50))
        .foregroundColor(.secondary)
      
      VStack(spacing: 8) {
        Text("No MQTT Data")
          .font(.title2)
          .fontWeight(.medium)
        
        Text("Please check MQTT connection...")
          .font(.subheadline)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      }
      
      Text("Waiting for data")
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 250)
  }
  
  @ViewBuilder
  private var controlMenu: some View {
    Menu {
      Section("Data Points") {
        windowSizeButton(name: "5 points", value: 5)
        windowSizeButton(name: "10 points", value: 10)
        windowSizeButton(name: "20 points", value: 20)
        windowSizeButton(name: "50 points", value: 50)
        windowSizeButton(name: "100 points", value: 100)
      }
      
      Section("Time Range") {
        timeRangeButton(name: "1 minute", value: 60)
        timeRangeButton(name: "5 minutes", value: 300)
        timeRangeButton(name: "15 minutes", value: 900)
        timeRangeButton(name: "30 minutes", value: 1800)
      }
    } label: {
      Image(systemName: "slider.horizontal.3")
        .foregroundColor(.blue)
    }
  }
  
  @ViewBuilder
  private func windowSizeButton(name: String, value: Int) -> some View {
    Button(action: {
      send(.changeWindowSize(value))
    }) {
      Label {
        Text(name)
      } icon: {
        if store.windowSize == value {
          Image(systemName: "checkmark")
        }
      }
    }
  }
  
  @ViewBuilder
  private func timeRangeButton(name: String, value: TimeInterval) -> some View {
    Button(action: {
      send(.changeTimeRange(value))
    }) {
      Label {
        Text(name)
      } icon: {
        if store.timeRange == value {
          Image(systemName: "checkmark")
        }
      }
    }
  }
  
  @ViewBuilder
  private func errorBanner(error: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundColor(.white)
        .font(.system(size: 16, weight: .medium))
      
      VStack(alignment: .leading, spacing: 2) {
        Text("Parse Error")
          .font(.headline)
          .foregroundColor(.white)
        
        Text(error)
          .font(.caption)
          .foregroundColor(.white.opacity(0.9))
          .lineLimit(2)
      }
      
      Spacer()
      
      Button(action: {
        send(.clearError)
      }) {
        Image(systemName: "xmark.circle.fill")
          .foregroundColor(.white.opacity(0.7))
          .font(.system(size: 20))
      }
      .buttonStyle(.plain)
    }
    .padding()
    .background(Color.red)
    .cornerRadius(12)
    .transition(.slide.combined(with: .opacity))
    .animation(.easeInOut(duration: 0.3), value: store.lastError != nil)
  }
  
  private func formatRelativeTime(_ date: Date) -> String {
    let interval = Date().timeIntervalSince(date)
    
    if interval < 60 {
      return "\(Int(interval))s ago"
    } else if interval < 3600 {
      return "\(Int(interval / 60))m ago"
    } else {
      return date.formatted(date: .omitted, time: .shortened)
    }
  }
}

#Preview {
  IfstatView(
    store: .init(
      initialState: IfstatFeature.State(
        topicName: ifstatOutputTopic,
        displayName: "Network Speed",
        unit: "bytes/s"
      ),
      reducer: {
        IfstatFeature()
      }, withDependencies: {
          $0.mqttClientKit = .previewValue
      }
    )
  )
}
