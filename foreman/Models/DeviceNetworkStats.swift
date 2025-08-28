//
//  DeviceNetworkStats.swift
//  foreman
//
//  Created by Claude on 2025/8/28.
//

import Foundation

struct DeviceSpeedData: Equatable, Identifiable {
  let id: String
  let deviceId: String
  let deviceName: String
  let uploadSpeed: Double  // Mbps
  let downloadSpeed: Double  // Mbps
  let timestamp: Date
  let connectionQuality: Double  // 0.0 to 1.0
  let latency: Int  // milliseconds
  let signalStrength: Int  // dBm
  
  init(
    deviceId: String,
    deviceName: String,
    uploadSpeed: Double,
    downloadSpeed: Double,
    timestamp: Date = Date(),
    connectionQuality: Double = 1.0,
    latency: Int = 50,
    signalStrength: Int = -30
  ) {
    self.id = "\(deviceId)_\(timestamp.timeIntervalSince1970)"
    self.deviceId = deviceId
    self.deviceName = deviceName
    self.uploadSpeed = uploadSpeed
    self.downloadSpeed = downloadSpeed
    self.timestamp = timestamp
    self.connectionQuality = connectionQuality
    self.latency = latency
    self.signalStrength = signalStrength
  }
}

struct NetworkMetrics: Equatable {
  let totalDevices: Int
  let averageUploadSpeed: Double  // Mbps
  let averageDownloadSpeed: Double  // Mbps
  let peakUploadSpeed: Double  // Mbps
  let peakDownloadSpeed: Double  // Mbps
  let totalBandwidthUsage: Double  // Mbps
  let averageLatency: Double  // milliseconds
  let averageConnectionQuality: Double  // 0.0 to 1.0
  
  static let empty = NetworkMetrics(
    totalDevices: 0,
    averageUploadSpeed: 0,
    averageDownloadSpeed: 0,
    peakUploadSpeed: 0,
    peakDownloadSpeed: 0,
    totalBandwidthUsage: 0,
    averageLatency: 0,
    averageConnectionQuality: 0
  )
}

struct ChartDataPoint: Equatable, Identifiable {
  let id: String
  let deviceId: String
  let speed: Double
  let type: SpeedType
  let timestamp: Date
  
  enum SpeedType: String, CaseIterable {
    case upload = "Upload"
    case download = "Download"
  }
  
  init(deviceId: String, speed: Double, type: SpeedType, timestamp: Date = Date()) {
    self.id = "\(deviceId)_\(type.rawValue)_\(timestamp.timeIntervalSince1970)"
    self.deviceId = deviceId
    self.speed = speed
    self.type = type
    self.timestamp = timestamp
  }
}

extension NetworkMetrics {
  init(from deviceData: [DeviceSpeedData]) {
    guard !deviceData.isEmpty else {
      self = .empty
      return
    }
    
    let uploadSpeeds = deviceData.map(\.uploadSpeed)
    let downloadSpeeds = deviceData.map(\.downloadSpeed)
    let latencies = deviceData.map { Double($0.latency) }
    let qualities = deviceData.map(\.connectionQuality)
    
    self.totalDevices = deviceData.count
    self.averageUploadSpeed = uploadSpeeds.reduce(0, +) / Double(uploadSpeeds.count)
    self.averageDownloadSpeed = downloadSpeeds.reduce(0, +) / Double(downloadSpeeds.count)
    self.peakUploadSpeed = uploadSpeeds.max() ?? 0
    self.peakDownloadSpeed = downloadSpeeds.max() ?? 0
    self.totalBandwidthUsage = (uploadSpeeds.reduce(0, +) + downloadSpeeds.reduce(0, +))
    self.averageLatency = latencies.reduce(0, +) / Double(latencies.count)
    self.averageConnectionQuality = qualities.reduce(0, +) / Double(qualities.count)
  }
}