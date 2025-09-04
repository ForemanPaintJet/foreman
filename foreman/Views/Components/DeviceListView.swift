//
//  DeviceListView.swift
//  foreman
//
//  Created by Claude on 2025/8/28.
//

import SwiftUI

struct DeviceListView: View {
  let devices: [DeviceSpeedData]
  let selectedDevices: Set<String>
  let onDeviceToggle: (String) -> Void
  let onDeviceDetails: (String) -> Void
  
  @State private var sortOption: SortOption = .name
  @State private var searchText = ""
  
  enum SortOption: String, CaseIterable {
    case name = "名稱"
    case uploadSpeed = "上傳速率"
    case downloadSpeed = "下載速率"
    case quality = "連接質量"
    
    func compare(_ lhs: DeviceSpeedData, _ rhs: DeviceSpeedData) -> Bool {
      switch self {
      case .name:
        return lhs.deviceName < rhs.deviceName
      case .uploadSpeed:
        return lhs.uploadSpeed > rhs.uploadSpeed
      case .downloadSpeed:
        return lhs.downloadSpeed > rhs.downloadSpeed
      case .quality:
        return lhs.connectionQuality > rhs.connectionQuality
      }
    }
  }
  
  private var latestDeviceData: [DeviceSpeedData] {
    let grouped = Dictionary(grouping: devices, by: \.deviceId)
    return grouped.compactMap { $1.max(by: { $0.timestamp < $1.timestamp }) }
  }
  
  private var filteredAndSortedDevices: [DeviceSpeedData] {
    let filtered = searchText.isEmpty 
      ? latestDeviceData
      : latestDeviceData.filter { device in
          device.deviceName.localizedCaseInsensitiveContains(searchText) ||
          device.deviceId.localizedCaseInsensitiveContains(searchText)
        }
    
    return filtered.sorted { sortOption.compare($0, $1) }
  }
  
  var body: some View {
    VStack(spacing: 0) {
      headerView
      
      if filteredAndSortedDevices.isEmpty {
        emptyStateView
      } else {
        deviceListContent
      }
    }
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
  }
  
  @ViewBuilder
  private var headerView: some View {
    VStack(spacing: 12) {
      HStack {
        Text("連接設備")
          .font(.headline)
          .fontWeight(.semibold)
        
        Spacer()
        
        Menu {
          ForEach(SortOption.allCases, id: \.self) { option in
            Button(action: { sortOption = option }) {
              Label {
                Text(option.rawValue)
              } icon: {
                if sortOption == option {
                  Image(systemName: "checkmark")
                }
              }
            }
          }
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "arrow.up.arrow.down")
            Text("排序")
          }
          .font(.caption)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
      }
      
      HStack {
        Image(systemName: "magnifyingglass")
          .foregroundColor(.secondary)
          .font(.caption)
        
        TextField("搜尋設備...", text: $searchText)
          .textFieldStyle(.plain)
          .font(.caption)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
    }
    .padding()
  }
  
  @ViewBuilder
  private var deviceListContent: some View {
    ScrollView {
      LazyVStack(spacing: 8) {
        ForEach(filteredAndSortedDevices) { device in
          DeviceRowView(
            device: device,
            isSelected: selectedDevices.contains(device.deviceId),
            onToggle: { onDeviceToggle(device.deviceId) },
            onDetails: { onDeviceDetails(device.deviceId) }
          )
        }
      }
      .padding(.horizontal)
      .padding(.bottom)
    }
  }
  
  @ViewBuilder
  private var emptyStateView: some View {
    VStack(spacing: 16) {
      Image(systemName: searchText.isEmpty ? "antenna.radiowaves.left.and.right.slash" : "magnifyingglass")
        .font(.system(size: 32))
        .foregroundColor(.secondary)
      
      Text(searchText.isEmpty ? "無連接設備" : "找不到符合的設備")
        .font(.title3)
        .fontWeight(.medium)
      
      Text(searchText.isEmpty 
           ? "等待設備連接到服務器..." 
           : "嘗試不同的搜尋關鍵字"
      )
        .font(.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 160)
  }
}

struct DeviceRowView: View {
  let device: DeviceSpeedData
  let isSelected: Bool
  let onToggle: () -> Void
  let onDetails: () -> Void
  
  private var connectionStatusColor: Color {
    switch device.connectionQuality {
    case 0.8...1.0: return .green
    case 0.6..<0.8: return .blue
    case 0.4..<0.6: return .orange
    default: return .red
    }
  }
  
  private var signalStrengthIcon: String {
    switch device.signalStrength {
    case -30...0: return "wifi"
    case -50...(-31): return "wifi"
    case -70...(-51): return "wifi"
    default: return "wifi.slash"
    }
  }
  
  var body: some View {
    HStack(spacing: 12) {
      Button(action: onToggle) {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.title2)
          .foregroundColor(isSelected ? .blue : .secondary)
      }
      .buttonStyle(.plain)
      
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text(device.deviceName)
            .font(.subheadline)
            .fontWeight(.medium)
          
          Spacer()
          
          HStack(spacing: 4) {
            Circle()
              .fill(connectionStatusColor)
              .frame(width: 8, height: 8)
            Text("\(Int(device.connectionQuality * 100))%")
              .font(.caption2)
              .foregroundColor(connectionStatusColor)
          }
        }
        
        HStack {
          Text(device.deviceId)
            .font(.caption)
            .foregroundColor(.secondary)
          
          Spacer()
          
          HStack(spacing: 12) {
            HStack(spacing: 4) {
              Image(systemName: "arrow.up")
                .font(.caption2)
                .foregroundColor(.blue)
              Text("\(device.uploadSpeed, specifier: "%.1f")")
                .font(.caption)
                .fontWeight(.medium)
            }
            
            HStack(spacing: 4) {
              Image(systemName: "arrow.down")
                .font(.caption2)
                .foregroundColor(.green)
              Text("\(device.downloadSpeed, specifier: "%.1f")")
                .font(.caption)
                .fontWeight(.medium)
            }
            
            Text("Mbps")
              .font(.caption2)
              .foregroundColor(.secondary)
          }
        }
        
        HStack {
          HStack(spacing: 4) {
            Image(systemName: signalStrengthIcon)
              .font(.caption2)
              .foregroundColor(.secondary)
            Text("\(device.signalStrength) dBm")
              .font(.caption2)
              .foregroundColor(.secondary)
          }
          
          Spacer()
          
          HStack(spacing: 4) {
            Image(systemName: "timer")
              .font(.caption2)
              .foregroundColor(.orange)
            Text("\(device.latency) ms")
              .font(.caption2)
              .foregroundColor(.secondary)
          }
        }
      }
      
      Button(action: onDetails) {
        Image(systemName: "info.circle")
          .font(.title3)
          .foregroundColor(.blue)
      }
      .buttonStyle(.plain)
    }
    .padding()
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
    )
    .animation(.easeInOut(duration: 0.2), value: isSelected)
  }
}

#Preview {
  DeviceListView(
    devices: mockDeviceListData,
    selectedDevices: Set(mockDeviceListData.prefix(2).map(\.deviceId)),
    onDeviceToggle: { _ in },
    onDeviceDetails: { _ in }
  )
}

private let mockDeviceListData: [DeviceSpeedData] = [
  DeviceSpeedData(
    deviceId: "device_001",
    deviceName: "iPhone 15 Pro",
    uploadSpeed: 45.2,
    downloadSpeed: 89.7,
    connectionQuality: 0.95,
    latency: 23,
    signalStrength: -35
  ),
  DeviceSpeedData(
    deviceId: "device_002",
    deviceName: "iPad Pro",
    uploadSpeed: 32.8,
    downloadSpeed: 76.1,
    connectionQuality: 0.82,
    latency: 45,
    signalStrength: -48
  ),
  DeviceSpeedData(
    deviceId: "device_003",
    deviceName: "MacBook Air",
    uploadSpeed: 58.9,
    downloadSpeed: 124.3,
    connectionQuality: 0.73,
    latency: 67,
    signalStrength: -55
  ),
  DeviceSpeedData(
    deviceId: "device_004",
    deviceName: "Apple Watch",
    uploadSpeed: 12.4,
    downloadSpeed: 28.6,
    connectionQuality: 0.45,
    latency: 98,
    signalStrength: -72
  ),
]