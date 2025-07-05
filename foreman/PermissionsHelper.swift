//
//  PermissionsHelper.swift
//  foreman
//
//  Created by Jed Lu on 2025/7/4.
//

import AVFoundation
import Foundation

class PermissionsHelper {
    static let shared = PermissionsHelper()

    private init() {}

    func requestCameraPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                print(granted ? "✅ Camera permission granted" : "❌ Camera permission denied")
                continuation.resume(returning: granted)
            }
        }
    }

    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                print(
                    granted ? "✅ Microphone permission granted" : "❌ Microphone permission denied")
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
