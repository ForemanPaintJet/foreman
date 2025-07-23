//
//  BatteryClient.swift
//  foreman
//
//  Created by Jed Lu on 2025/7/22.
//

import Combine
import ComposableArchitecture
import UIKit

struct BatteryClient {
    var batteryLevelPublisher: () -> AnyPublisher<Int, Never>
}

extension BatteryClient: DependencyKey {
    static var liveValue: BatteryClient {
        BatteryClient {
            let subject = PassthroughSubject<Int, Never>()
            UIDevice.current.isBatteryMonitoringEnabled = true

            let observer = NotificationCenter.default.addObserver(
                forName: UIDevice.batteryLevelDidChangeNotification,
                object: nil,
                queue: .main
            ) { _ in
                subject.send(Int(UIDevice.current.batteryLevel * 100))
            }

            // 先發一次當前電量
            subject.send(Int(UIDevice.current.batteryLevel * 100))

            return subject
                .handleEvents(receiveCancel: {
                    NotificationCenter.default.removeObserver(observer)
                })
                .eraseToAnyPublisher()
        }
    }

    static var testValue: BatteryClient {
        BatteryClient {
            Timer.publish(every: 1.0, on: .main, in: .common)
                .autoconnect()
                .scan(0) { last, _ in min(last + 1, 100) }
                .eraseToAnyPublisher()
        }
    }
}

extension DependencyValues {
    var batteryClient: BatteryClient {
        get { self[BatteryClient.self] }
        set { self[BatteryClient.self] = newValue }
    }
}
