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
      .navigationTitle("\(store.topicName) 監控")
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
          Text("MQTT 數據監控")
            .font(.title2)
            .fontWeight(.bold)
          
          Text("Topic: \(store.topicName)")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        
        Spacer()
        
        VStack(alignment: .trailing, spacing: 4) {
          dataSourceIndicator
          
          Text("更新：\(formatRelativeTime(store.lastRefreshTime))")
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
      
      Text("即時資料")
        .font(.caption)
        .foregroundColor(.blue)
    }
  }
  
  @ViewBuilder
  private var dataVisualizationCard: some View {
    VStack(spacing: 16) {
      // Current value display
      if let latestData = store.latestData {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("當前數值")
              .font(.headline)
              .foregroundColor(.secondary)
            
            Text("\(latestData.value)")
              .font(.largeTitle.bold())
              .foregroundColor(.primary)
          }
          
          Spacer()
          
          Text("\(latestData.timestamp, format: .dateTime.hour().minute().second())")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
      }
      
      // Chart
      VStack(alignment: .leading, spacing: 8) {
        Text("數值趨勢")
          .font(.headline)
          .foregroundColor(.primary)
        
        Chart(store.interfaceData, id: \.timestamp) { data in
          LineMark(
            x: .value("時間", data.timestamp),
            y: .value("數值", data.value)
          )
          .foregroundStyle(.blue)
          .symbol(.circle)
          .symbolSize(30)
          
          AreaMark(
            x: .value("時間", data.timestamp),
            y: .value("數值", data.value)
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
        Text("無 MQTT 數據")
          .font(.title2)
          .fontWeight(.medium)
        
        Text("請檢查 MQTT 連線是否正常...")
          .font(.subheadline)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      }
      
      Text("等待數據中")
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 250)
  }
  
  @ViewBuilder
  private var controlMenu: some View {
    Menu {
      Section("時間範圍") {
        timeRangeButton(name: "1 分鐘", value: 60)
        timeRangeButton(name: "5 分鐘", value: 300)
        timeRangeButton(name: "15 分鐘", value: 900)
        timeRangeButton(name: "30 分鐘", value: 1800)
      }
    } label: {
      Image(systemName: "slider.horizontal.3")
        .foregroundColor(.blue)
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
        Text("解析錯誤")
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
      return "\(Int(interval))秒前"
    } else if interval < 3600 {
      return "\(Int(interval / 60))分前"
    } else {
      return date.formatted(date: .omitted, time: .shortened)
    }
  }
}

#Preview {
  IfstatView(
    store: .init(
      initialState: IfstatFeature.State(
        topicName: ifstatOutputTopic
      ),
      reducer: {
        IfstatFeature()
      }, withDependencies: {
          $0.mqttClientKit = .previewValue
      }
    )
  )
}
