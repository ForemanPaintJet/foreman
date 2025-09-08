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

// MARK: - Gesture Types

enum GestureType: String, CaseIterable, Identifiable {
  case emergencyStop = "emergecy_stop"
  case extendBoom = "extend_boom"
  case followMe = "follow_me"
  case idle = "idle"
  case loadLower = "load_lower"
  case lowerBoom = "lower_boom"
  case raiseBoom = "raise_boom"
  case retractBoom = "retract_boom"
  case stop = "stop"
  case swingLeft = "swing_left"
  case swingRight = "swing_right"
  
  var id: String { rawValue }
  
  var displayName: String {
    switch self {
    case .emergencyStop: return "Emergency Stop"
    case .extendBoom: return "Extend Boom"
    case .followMe: return "Follow Me"
    case .idle: return "Idle"
    case .loadLower: return "Load Lower"
    case .lowerBoom: return "Lower Boom"
    case .raiseBoom: return "Raise Boom"
    case .retractBoom: return "Retract Boom"
    case .stop: return "Stop"
    case .swingLeft: return "Swing Left"
    case .swingRight: return "Swing Right"
    }
  }
  
  var imageName: String {
    return rawValue
  }
}

// MARK: - Rotating Gradient Border View

struct RotatingGradientBorderView<Content: View>: View {
  let content: () -> Content
  @State private var rotation: Double = 0
  
  var body: some View {
    ZStack {
      // Rotating gradient background
      RoundedRectangle(cornerRadius: 16)
        .fill(
          AngularGradient(
            colors: [.green, .blue, .purple, .pink, .orange, .green],
            center: .center,
            startAngle: .degrees(rotation),
            endAngle: .degrees(rotation + 360)
          )
        )
        .frame(width: 148, height: 148)
        .rotationEffect(.degrees(rotation))
        .onAppear {
          withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            rotation = 360
          }
        }
      
      // Content with mask
      content()
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color.clear, lineWidth: 4)
        )
    }
  }
}

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
              .containerRelativeFrame(.vertical) { length, axis in
                // 根據螢幕高度動態調整 drawer 高度
                return store.isMiniMode ? min(80, length * 0.15) : min(300, length * 0.6)
              }
              .transition(.move(edge: .top).combined(with: .opacity))
          }
        }
        .overlay(alignment: .topTrailing) {
          // Control buttons overlay (always on top)
          VStack {
            // Dynamic top spacing based on drawer state
            if store.isDrawerOpen {
              Spacer()
                .containerRelativeFrame(.vertical) { length, axis in
                  // 對應 drawer 的動態高度
                  return store.isMiniMode ? min(80, length * 0.15) : min(300, length * 0.6)
                }
            }
            
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
        .overlay(alignment: .bottom) {
          // Bottom drawer for gesture gallery
          if store.showInfoPopover {
            gestureGalleryDrawer
              .containerRelativeFrame(.vertical) { length, axis in
                // Dynamic height based on screen size
                return min(200, length * 0.25)
              }
              .transition(
                .asymmetric(
                  insertion: .move(edge: .bottom)
                    .combined(with: .opacity)
                    .combined(with: .scale(scale: 0.95, anchor: .bottom)),
                  removal: .move(edge: .bottom)
                    .combined(with: .opacity)
                    .combined(with: .scale(scale: 1.05, anchor: .bottom))
                )
              )
          }
        }
        .overlay(alignment: .bottomTrailing) {
          // Fixed status cell in bottom-right corner
          Button(action: {
            send(.showInfo(!store.showInfoPopover))
          }) {
            VStack(spacing: 8) {
              Text(store.currentRunningGesture.displayName)
                .font(.callout)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(minHeight: 35)
              
              if store.currentRunningGesture == .idle {
                // Static border for idle state with subtle shadows
                Image(store.currentRunningGesture.imageName)
                  .resizable()
                  .aspectRatio(contentMode: .fill)
                  .frame(width: 140, height: 140)
                  .clipped()
                  .overlay(
                    RoundedRectangle(cornerRadius: 12)
                      .stroke(Color.secondary, lineWidth: 2)
                  )
                  .cornerRadius(12)
                  .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                  .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
              } else {
                // Animated gradient border for active state with enhanced shadows
                RotatingGradientBorderView(
                  content: {
                    Image(store.currentRunningGesture.imageName)
                      .resizable()
                      .aspectRatio(contentMode: .fill)
                      .frame(width: 140, height: 140)
                      .clipped()
                      .cornerRadius(12)
                  }
                )
                .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 0)
                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
              }
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
          }
          .buttonStyle(.plain)
          .scaleEffect(store.showInfoPopover ? 0.95 : 1.0)
          .animation(.easeInOut(duration: 0.15), value: store.showInfoPopover)
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
    .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0), value: store.showInfoPopover)
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
              // Sensor Status
              SensorNodeStatusView(
                store: store.scope(
                  state: \.sensorNodeStatus,
                  action: \.sensorNodeStatus
                )
              )
              .containerRelativeFrame(.horizontal) { length, axis in
                // 響應式調整 sensor 狀態視圖寬度
                return min(300, max(200, length * 0.3))
              }
              
              // 動態生成所有 ifstat 監控項目
              ForEach(store.scope(state: \.monitoringItems, action: \.monitoringItems)) { itemStore in
                IfstatView(store: itemStore)
                  .containerRelativeFrame(.horizontal) { length, axis in
                    // 根據可用寬度調整監控項目寬度
                    return store.isMiniMode ? 200 : min(300, length * 0.25)
                  }
              }
            }
            .padding(.horizontal)
          }
          .frame(maxHeight: .infinity)
          .transition(.scale.combined(with: .opacity))
        } else {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
              // Sensor Status
              SensorNodeStatusView(
                store: store.scope(
                  state: \.sensorNodeStatus,
                  action: \.sensorNodeStatus
                )
              )
              .containerRelativeFrame(.horizontal) { length, axis in
                // 響應式調整 sensor 狀態視圖寬度
                return min(300, max(200, length * 0.3))
              }
              
              // 動態生成所有 full-size 監控項目
              ForEach(store.scope(state: \.monitoringItems, action: \.monitoringItems)) { itemStore in
                IfstatView(store: itemStore)
                  .containerRelativeFrame(.horizontal) { length, axis in
                    // 根據可用寬度調整監控項目寬度
                    return store.isMiniMode ? 200 : min(300, length * 0.25)
                  }
              }
            }
            .padding(.horizontal)
          }
          .frame(maxHeight: .infinity)
          .transition(.scale.combined(with: .opacity))
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      
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
  
  
  @ViewBuilder
  private var gestureGalleryDrawer: some View {
    VStack(spacing: 0) {
      // Header with floating close button
      HStack {
        Spacer()
        Image(systemName: "hand.wave.fill")
          .foregroundColor(.blue)
          .font(.headline)
        Text("Supported Gestures")
          .font(.headline)
          .fontWeight(.medium)
        Spacer()
      }
      .padding(.horizontal)
      .padding(.top, 12)
      .padding(.bottom, 8)
      .overlay(alignment: .topTrailing) {
        // Close button positioned above the drawer
        Button(action: {
          send(.showInfo(false))
        }) {
          HStack(spacing: 6) {
            Image(systemName: "hand.wave")
              .font(.system(size: 16, weight: .medium))
          }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .foregroundColor(.primary)
        .buttonStyle(.plain)
        .shadow(radius: 2)
        .offset(y: -60)
        .padding(.trailing)
        .scaleEffect(store.showInfoPopover ? 1.0 : 0.6)
        .opacity(store.showInfoPopover ? 1.0 : 0.0)
        .animation(
          .spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)
            .delay(0.2),
          value: store.showInfoPopover
        )
      }
      
      // Pure horizontal ScrollView with gesture gallery
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 20) {
          ForEach(Array(gestureTypes.enumerated()), id: \.element.id) { index, gestureType in
            Button(action: {
              send(.setRunningGesture(gestureType))
            }) {
              VStack(spacing: 8) {
                Text(gestureType.displayName)
                  .font(.callout)
                  .fontWeight(.semibold)
                  .foregroundColor(.primary)
                  .multilineTextAlignment(.center)
                  .lineLimit(2)
                  .frame(minHeight: 35)
                
                Image(gestureType.imageName)
                  .resizable()
                  .aspectRatio(contentMode: .fill)
                  .frame(width: 140, height: 140)
                  .clipped()
                  .cornerRadius(12)
                  .shadow(radius: 4)
              }
            }
            .buttonStyle(.plain)
            .scaleEffect(store.showInfoPopover ? 1.0 : 0.8)
            .opacity(store.showInfoPopover ? 1.0 : 0)
            .animation(
              .spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)
                .delay(Double(index) * 0.05),
              value: store.showInfoPopover
            )
          }
        }
        .padding(.leading, 20)
        .padding(.trailing, 200)
      }
      .frame(maxHeight: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemGray6))
  }
  
  private var gestureTypes: [GestureType] {
    // All available gesture types (excluding idle which only appears in status cell)
    return GestureType.allCases.filter { $0 != .idle }
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
          lastUpdateTime: Date(),
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
