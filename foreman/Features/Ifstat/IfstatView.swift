//
//  IfstatView.swift
//  foreman
//
//  Created by Claude on 2025/8/28.
//

import ComposableArchitecture
import OSLog
import SwiftUI

@ViewAction(for: IfstatFeature.self)
struct IfstatView: View {
  @Bindable var store: StoreOf<IfstatFeature>
  private let logger = Logger(subsystem: "foreman", category: "IfstatView")
  
  var body: some View {
    IfstatStatsView(
      interfaceData: store.interfaceData,
      targetInterface: store.targetInterface,
      timeRange: store.timeRange,
      lastRefreshTime: store.lastRefreshTime,
      isSubscribed: store.isSubscribed,
      onTimeRangeChange: { newRange in
        send(.changeTimeRange(newRange))
      }
    )
    .task {
      send(.task)
    }
    .onDisappear {
      send(.teardown)
    }
  }
}

#Preview {
  IfstatView(
    store: .init(
      initialState: IfstatFeature.State(
        interfaceData: mockIfstatPreviewData,
        targetInterface: "en0"
      ),
      reducer: {
        IfstatFeature()
      }
    )
  )
}

private let mockIfstatPreviewData: [NetworkInterfaceData] = {
  let interfaceName = "en0"
  
  return (0..<20).map { i in
    return NetworkInterfaceData(
      interfaceName: interfaceName,
      uploadSpeed: Double.random(in: 100...1000),
      downloadSpeed: Double.random(in: 200...2000),
      speedUnit: .megabytesPerSecond,
      timestamp: Date().addingTimeInterval(-Double(i * 15))
    )
  }
}()