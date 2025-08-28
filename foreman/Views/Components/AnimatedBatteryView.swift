//
//  AnimatedBatteryView.swift
//  foreman
//
//  Created by Jed Lu on 2025/7/22.
//
import SwiftUI

struct AnimatedBatteryView: View {
    let bLevel: Int
    let isCharging: Bool

    var body: some View {
        ZStack {
            Image(systemName: batterySymbolName)
                .font(.system(size: 60))
                .foregroundColor(batteryColor)
                .scaleEffect(isCharging ? 1.1 : 1.0)
                .animation(
                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                    value: isCharging
                )
            Text("\(bLevel)%")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .shadow(radius: 2)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: bLevel)
        }
    }

    private var batterySymbolName: String {
        if isCharging {
            return "battery.100.bolt"
        }

        switch bLevel {
        case 0:
            return "battery.0"
        case 1..<25:
            return "battery.25"
        case 25..<50:
            return "battery.50"
        case 50..<75:
            return "battery.75"
        default:
            return "battery.100"
        }
    }

    private var batteryColor: Color {
        if isCharging { return .green }

        switch bLevel {
        case 0..<20: return .red
        case 20..<50: return .orange
        default: return .green
        }
    }
}

#Preview {
    TimelineView(.animation) { content in
        let seconds = Int(content.date.timeIntervalSinceReferenceDate) % 100
        AnimatedBatteryView(bLevel: seconds, isCharging: false)
    }
}
