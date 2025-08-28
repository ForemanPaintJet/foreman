//
//  NetworkInterfaceData.swift
//  foreman
//
//  Created by Claude on 2025/8/28.
//

import Foundation

struct NetworkInterfaceData: Equatable, Identifiable {
    let id: String
    let interfaceName: String // eth0, wlan0, en0, etc.
    let uploadSpeed: Double // Upload speed value
    let downloadSpeed: Double // Download speed value
    let speedUnit: SpeedUnit // KB/s, MB/s, GB/s
    let timestamp: Date
  
    enum SpeedUnit: String, CaseIterable, Equatable {
        case bytesPerSecond = "B/s"
        case kilobytesPerSecond = "KB/s"
        case megabytesPerSecond = "MB/s"
        case gigabytesPerSecond = "GB/s"
    
        var displayName: String {
            rawValue
        }
    
        var multiplier: Double {
            switch self {
            case .bytesPerSecond: 1
            case .kilobytesPerSecond: 1024
            case .megabytesPerSecond: 1024 * 1024
            case .gigabytesPerSecond: 1024 * 1024 * 1024
            }
        }
    }
  
    init(
        interfaceName: String,
        uploadSpeed: Double,
        downloadSpeed: Double,
        speedUnit: SpeedUnit = .kilobytesPerSecond,
        timestamp: Date = Date()
    ) {
        self.id = "\(interfaceName)_\(timestamp.timeIntervalSince1970)"
        self.interfaceName = interfaceName
        self.uploadSpeed = uploadSpeed
        self.downloadSpeed = downloadSpeed
        self.speedUnit = speedUnit
        self.timestamp = timestamp
    }
  
    // Convert speeds to a common unit for comparison/calculation
    var uploadSpeedInBytes: Double {
        uploadSpeed * speedUnit.multiplier
    }
  
    var downloadSpeedInBytes: Double {
        downloadSpeed * speedUnit.multiplier
    }
  
    // Helper to get human-readable speed with auto-scaling
    var formattedUploadSpeed: (value: Double, unit: String) {
        formatSpeed(uploadSpeedInBytes)
    }
  
    var formattedDownloadSpeed: (value: Double, unit: String) {
        formatSpeed(downloadSpeedInBytes)
    }
  
    private func formatSpeed(_ bytesPerSecond: Double) -> (value: Double, unit: String) {
        if bytesPerSecond >= SpeedUnit.gigabytesPerSecond.multiplier {
            (bytesPerSecond / SpeedUnit.gigabytesPerSecond.multiplier, SpeedUnit.gigabytesPerSecond.rawValue)
        } else if bytesPerSecond >= SpeedUnit.megabytesPerSecond.multiplier {
            (bytesPerSecond / SpeedUnit.megabytesPerSecond.multiplier, SpeedUnit.megabytesPerSecond.rawValue)
        } else if bytesPerSecond >= SpeedUnit.kilobytesPerSecond.multiplier {
            (bytesPerSecond / SpeedUnit.kilobytesPerSecond.multiplier, SpeedUnit.kilobytesPerSecond.rawValue)
        } else {
            (bytesPerSecond, SpeedUnit.bytesPerSecond.rawValue)
        }
    }
}
