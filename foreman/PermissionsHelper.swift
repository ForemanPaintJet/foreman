//
//  PermissionsHelper.swift
//  foreman
//
//  Created by Jed Lu on 2025/7/4.
//

import AVFoundation
import Foundation
import OSLog

class PermissionsHelper {
    static let shared = PermissionsHelper()
    private static let logger = Logger(subsystem: "foreman", category: "PermissionsHelper")

    private init() {}

    func requestCameraPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    Self.logger.info("✅ Camera permission granted")
                } else {
                    Self.logger.error("❌ Camera permission denied")
                }
                continuation.resume(returning: granted)
            }
        }
    }

    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    Self.logger.info("✅ Microphone permission granted")
                } else {
                    Self.logger.error("❌ Microphone permission denied")
                }
                continuation.resume(returning: granted)
            }
        }
    }

    func checkCameraPermission() -> AVAuthorizationStatus {
        return AVCaptureDevice.authorizationStatus(for: .video)
    }

    func checkMicrophonePermission() -> AVAuthorizationStatus {
        return AVCaptureDevice.authorizationStatus(for: .audio)
    }

    func requestAllPermissions() async -> (camera: Bool, microphone: Bool) {
        async let cameraPermission = requestCameraPermission()
        async let microphonePermission = requestMicrophonePermission()

        let camera = await cameraPermission
        let microphone = await microphonePermission

        return (camera: camera, microphone: microphone)
    }
}
