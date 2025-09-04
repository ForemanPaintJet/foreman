//
//  SensorNodeStatusView.swift
//  foreman
//
//  Created by Claude on 2025/9/4.
//

import ComposableArchitecture
import MQTTNIO
import NIOCore
import OSLog
import SwiftUI

@ViewAction(for: SensorNodeStatusFeature.self)
struct SensorNodeStatusView: View {
  @Bindable var store: StoreOf<SensorNodeStatusFeature>
  private let logger = Logger(subsystem: "foreman", category: "SensorNodeStatusView")
  
  private var hasData: Bool {
    !store.sensorNodes.isEmpty
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
            sensorStatusGrid
          } else {
            emptyStateView
          }
        }
        .padding()
      }
      .navigationTitle("Sensor Node Status")
      .navigationBarTitleDisplayMode(.inline)
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
          Text("Sensor Node Monitoring")
            .font(.title2)
            .fontWeight(.bold)
          
          Text("Topic: \(store.topicName)")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        
        Spacer()
        
        VStack(alignment: .trailing, spacing: 4) {
          systemHealthIndicator
          
          Text("Updated: \(formatRelativeTime(store.lastUpdateTime))")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      
      
      Divider()
        .padding(.horizontal, -16)
    }
  }
  
  @ViewBuilder
  private var systemHealthIndicator: some View {
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
  private var sensorStatusGrid: some View {
    LazyVGrid(columns: [
      GridItem(.flexible()),
      GridItem(.flexible())
    ], spacing: 16) {
      ForEach(store.sensorNodes, id: \.name) { sensor in
        sensorStatusCard(sensor: sensor)
      }
    }
    .transition(.scale.combined(with: .opacity))
    .animation(.easeInOut(duration: 0.3), value: hasData)
  }
  
  @ViewBuilder
  private func sensorStatusCard(sensor: SensorNodeStatus) -> some View {
    VStack(spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(formatSensorName(sensor.name))
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.primary)
            .lineLimit(2)
          
          Text(sensor.status.description)
            .font(.subheadline)
            .foregroundColor(statusColor(sensor.status))
        }
        
        Spacer()
        
        statusIndicator(for: sensor.status)
      }
      
      // Last update time
      HStack {
        Text("Updated: \(formatRelativeTime(store.lastUpdateTime))")
          .font(.caption)
          .foregroundColor(.secondary)
        
        Spacer()
      }
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(radius: 2)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(statusColor(sensor.status).opacity(0.3), lineWidth: 1)
    )
  }
  
  @ViewBuilder
  private func statusIndicator(for status: SensorNodeStatusValue) -> some View {
    Circle()
      .fill(statusColor(status))
      .frame(width: 24, height: 24)
      .overlay(
        Circle()
          .stroke(statusColor(status).opacity(0.3), lineWidth: 2)
          .frame(width: 32, height: 32)
      )
      .scaleEffect(status == .working ? 1.0 : 0.9)
      .animation(
        status == .working ? 
          .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : 
          .default,
        value: status
      )
  }
  
  
  private func statusColor(_ status: SensorNodeStatusValue) -> Color {
    switch status {
    case .working:
      return .green
    case .degraded:
      return .orange
    case .disconnected:
      return .red
    }
  }
  
  private func formatSensorName(_ name: String) -> String {
    // Convert "platform_sensor_node" to "Platform Sensor"
    let components = name.replacingOccurrences(of: "_sensor_node", with: "")
      .components(separatedBy: "_")
    return components.map { $0.capitalized }.joined(separator: " ")
  }
  
  @ViewBuilder
  private var emptyStateView: some View {
    VStack(spacing: 24) {
      Image(systemName: "sensor.tag.radiowaves.forward.fill")
        .font(.system(size: 50))
        .foregroundColor(.secondary)
      
      VStack(spacing: 8) {
        Text("No Sensor Data")
          .font(.title2)
          .fontWeight(.medium)
        
        Text("Waiting for sensor node status updates...")
          .font(.subheadline)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      }
      
      Text("Check MQTT connection")
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 250)
  }
  
  @ViewBuilder
  private func errorBanner(error: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundColor(.white)
        .font(.system(size: 16, weight: .medium))
      
      VStack(alignment: .leading, spacing: 2) {
        Text("Sensor Error")
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
  SensorNodeStatusView(
    store: .init(
      initialState: SensorNodeStatusFeature.State(
        sensorNodes: [
          SensorNodeStatus(name: "platform_sensor_node", status: .working),
          SensorNodeStatus(name: "telescope_sensor_node", status: .working),
          SensorNodeStatus(name: "turntable_sensor_node", status: .degraded),
          SensorNodeStatus(name: "jib_sensor_node", status: .disconnected)
        ],
        topicName: sensorNodeStatusTopic,
        displayName: "Sensor Status Monitor",
        lastUpdateTime: Date()
      ),
      reducer: {
        SensorNodeStatusFeature()
      }, withDependencies: {
        $0.mqttClientKit = .previewValue
      }
    )
  )
}