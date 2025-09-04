//
//  IfstatStatsView.swift
//  foreman
//
//  Created by Claude on 2025/8/28.
//

import SwiftUI

struct IfstatStatsView: View {
  let interfaceData: [NetworkInterfaceData]
  let targetInterface: String
  let timeRange: TimeInterval
  let lastRefreshTime: Date
  let isSubscribed: Bool
  let onTimeRangeChange: (TimeInterval) -> Void
  
  private var hasData: Bool {
    !interfaceData.isEmpty
  }
  
  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 20) {
          headerView
          
          if hasData {
            interfaceCard
          } else {
            emptyStateView
          }
        }
        .padding()
      }
      .navigationTitle("\(targetInterface) 監控")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          controlMenu
        }
      }
    }
    .navigationViewStyle(.stack)
  }
  
  @ViewBuilder
  private var headerView: some View {
    VStack(spacing: 8) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("ifstat 監控")
            .font(.title2)
            .fontWeight(.bold)
          
          Text("接口：\(targetInterface)")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        
        Spacer()
        
        VStack(alignment: .trailing, spacing: 4) {
          dataSourceIndicator
          
          Text("更新：\(formatRelativeTime(lastRefreshTime))")
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
        .fill(isSubscribed ? .blue : .gray)
        .frame(width: 8, height: 8)
        .scaleEffect(isSubscribed ? 1.0 : 0.8)
        .animation(
          isSubscribed 
            ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true) 
            : .default,
          value: isSubscribed
        )
      
      Text(isSubscribed ? "即時資料" : "模擬資料")
        .font(.caption)
        .foregroundColor(isSubscribed ? .blue : .gray)
    }
  }
  
  
  @ViewBuilder
  private var interfaceCard: some View {
    SimpleInterfaceCard(
      interfaceData: interfaceData,
      timeRange: timeRange
    )
    .transition(.scale.combined(with: .opacity))
    .animation(.easeInOut(duration: 0.3), value: hasData)
  }
  
  @ViewBuilder
  private var emptyStateView: some View {
    VStack(spacing: 24) {
      Image(systemName: "network.slash")
        .font(.system(size: 50))
        .foregroundColor(.secondary)
      
      VStack(spacing: 8) {
        Text("無網路接口數據")
          .font(.title2)
          .fontWeight(.medium)
        
        Text("請檢查 ifstat 是否正在運行...")
          .font(.subheadline)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      }
      
      Text("無數據")
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
      onTimeRangeChange(value)
    }) {
      Label {
        Text(name)
      } icon: {
        if timeRange == value {
          Image(systemName: "checkmark")
        }
      }
    }
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
  let mockData = generateMockIfstatData()
  
  return IfstatStatsView(
    interfaceData: mockData,
    targetInterface: "en0",
    timeRange: 300,
    lastRefreshTime: Date().addingTimeInterval(-30),
    isSubscribed: true,
    onTimeRangeChange: { _ in }
  )
}

private func generateMockIfstatData() -> [NetworkInterfaceData] {
  let interfaceName = "en0"
  
  return (0..<15).map { i in
    return NetworkInterfaceData(
      interfaceName: interfaceName,
      uploadSpeed: Double.random(in: 50...500),
      downloadSpeed: Double.random(in: 100...1000),
      speedUnit: .megabytesPerSecond,
      timestamp: Date().addingTimeInterval(-Double(i * 20))
    )
  }
}