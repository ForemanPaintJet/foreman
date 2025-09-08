//
//  DashboardView.swift
//  foreman
//
//  Created by Claude on 2025/9/5.
//

import Charts
import ComposableArchitecture
import MQTTNIO
import NIOCore
import OSLog
import SwiftUI

@ViewAction(for: DashboardFeature.self)
struct DashboardView: View {
  @Bindable var store: StoreOf<DashboardFeature>
  private let logger = Logger(subsystem: "foreman", category: "DashboardView")
  
  var body: some View {
    GeometryReader { geometry in
      // Main content area - DirectVideoCallView (full screen)
      mainContentArea
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
          // Top drawer for monitoring panels (floating overlay)
          if store.isDrawerOpen {
            monitoringDrawer
              .frame(height: store.isMiniMode ? 80 : 400)
              .transition(.move(edge: .top).combined(with: .opacity))
          }
        }
        .overlay(alignment: .topTrailing) {
          // Control buttons overlay (always on top)
          VStack {
            HStack {
              Spacer()
              HStack(spacing: 8) {
                // Mini mode toggle button (only show when drawer is open)
                if store.isDrawerOpen {
                  Button(action: {
                    send(.toggleMiniMode)
                  }) {
                    Image(systemName: store.isMiniMode ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                      .font(.system(size: 16, weight: .medium))
                  }
                  .padding(.horizontal, 12)
                  .padding(.vertical, 8)
                  .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                  .foregroundColor(.primary)
                  .buttonStyle(.plain)
                  .shadow(radius: 2)
                  .transition(.scale.combined(with: .opacity))
                }
                
                drawerToggleButton
              }
            }
            Spacer()
          }
          .padding()
        }
        .onAppear {
          // Set compact layout based on screen size
          send(.setCompactLayout(geometry.size.width < 1024))
        }
        .onChange(of: geometry.size) { _, newSize in
          send(.setCompactLayout(newSize.width < 1024))
        }
    }
    .task {
      send(.task)
    }
    .onDisappear {
      send(.teardown)
    }
    .animation(.easeInOut(duration: 0.3), value: store.isDrawerOpen)
  }
  
  @ViewBuilder
  private var mainContentArea: some View {
    // Enhanced DirectVideoCallView (full screen)
    DirectVideoCallView(
      store: store.scope(
        state: \.directVideoCall,
        action: \.directVideoCall
      )
    )
  }
  
  @ViewBuilder
  private var drawerToggleButton: some View {
    Button(action: {
      send(.toggleDrawer)
    }) {
      HStack(spacing: 6) {
        Image(systemName: store.isDrawerOpen ? "sidebar.right" : "chart.bar.fill")
          .font(.system(size: 16, weight: .medium))
        
        if !store.isDrawerOpen {
          Text("Monitor")
            .font(.caption)
            .fontWeight(.medium)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
      .foregroundColor(.primary)
    }
    .buttonStyle(.plain)
    .shadow(radius: 2)
  }
  
  @ViewBuilder
  private var monitoringDrawer: some View {
    HStack(spacing: 0) {
      // Drawer content
      VStack(spacing: 0) {
        if store.isMiniMode {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
              // 動態生成所有 ifstat 監控項目
              ForEach(store.scope(state: \.monitoringItems, action: \.monitoringItems)) { itemStore in
                IfstatView(store: itemStore)
              }
              
              // Sensor Status
              SensorNodeStatusView(
                store: store.scope(
                  state: \.sensorNodeStatus,
                  action: \.sensorNodeStatus
                )
              )
            }
            .padding(.horizontal)
          }
          .transition(.scale.combined(with: .opacity))
        } else {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
              // 動態生成所有 full-size 監控項目
              ForEach(store.scope(state: \.monitoringItems, action: \.monitoringItems)) { itemStore in
                IfstatView(store: itemStore)
                  .frame(width: 300)
              }
              
              // Sensor Status
              SensorNodeStatusView(
                store: store.scope(
                  state: \.sensorNodeStatus,
                  action: \.sensorNodeStatus
                )
              )
              .frame(width: 300)
            }
            .padding(.horizontal)
          }
          .transition(.scale.combined(with: .opacity))
        }
      }
      .frame(maxWidth: .infinity)
      
      // Resize handle
      Rectangle()
        .fill(Color.gray.opacity(0.3))
        .frame(width: 4)
        .gesture(
          DragGesture()
            .onChanged { value in
              let newHeight = store.drawerWidth - value.translation.height
              send(.setDrawerWidth(newHeight))
            }
        )
    }
    .background(Color(.systemGray6))
    .animation(.easeInOut(duration: 0.3), value: store.isMiniMode)
  }
}


#Preview {
  DashboardView(
    store: .init(
      initialState: DashboardFeature.State(
        sensorNodeStatus: SensorNodeStatusFeature.State(
          sensorNodes: [
            SensorNodeStatus(name: "platform_sensor_node", status: .working),
            SensorNodeStatus(name: "telescope_sensor_node", status: .working),
            SensorNodeStatus(name: "turntable_sensor_node", status: .degraded),
            SensorNodeStatus(name: "jib_sensor_node", status: .disconnected)
          ],
          topicName: sensorNodeStatusTopic,
          displayName: "Sensor Status Monitor",
          lastUpdateTime: Date()
        )
      ),
      reducer: {
        DashboardFeature()
      }, withDependencies: {
        $0.mqttClientKit = .previewValue
        $0.batteryClient = .testValue
      }
    )
  )
}
