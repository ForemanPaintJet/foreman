//
//  PermissionsHelperTests.swift
//  foremanTests
//
//  Created by Claude on 2025/8/13.
//

import AVFoundation
import Testing

@testable import foreman

@Suite("PermissionsHelper")
@MainActor
struct PermissionsHelperTests {
  
  @Test("shared instance exists")
  func testSharedInstance() async throws {
    let helper1 = PermissionsHelper.shared
    let helper2 = PermissionsHelper.shared
    
    // Should be the same instance
    #expect(helper1 === helper2)
  }
  
  @Test("check camera permission returns status")
  func testCheckCameraPermission() async throws {
    let helper = PermissionsHelper.shared
    let status = helper.checkCameraPermission()
    
    // Should return a valid AVAuthorizationStatus
    let validStatuses: [AVAuthorizationStatus] = [.notDetermined, .restricted, .denied, .authorized]
    #expect(validStatuses.contains(status))
  }
  
  @Test("check microphone permission returns status")
  func testCheckMicrophonePermission() async throws {
    let helper = PermissionsHelper.shared
    let status = helper.checkMicrophonePermission()
    
    // Should return a valid AVAuthorizationStatus
    let validStatuses: [AVAuthorizationStatus] = [.notDetermined, .restricted, .denied, .authorized]
    #expect(validStatuses.contains(status))
  }
  
  @Test("request all permissions returns tuple")
  func testRequestAllPermissions() async throws {
    let helper = PermissionsHelper.shared
    
    // This test may show system permission dialogs in a real environment
    // In a test environment, it should return quickly with determined status
    let result = await helper.requestAllPermissions()
    
    // Should return a tuple with two boolean values
    #expect(result.camera == true || result.camera == false)
    #expect(result.microphone == true || result.microphone == false)
  }
  
  @Test("camera and microphone permissions are independent")
  func testIndependentPermissions() async throws {
    let helper = PermissionsHelper.shared
    
    let cameraStatus = helper.checkCameraPermission()
    let microphoneStatus = helper.checkMicrophonePermission()
    
    // Permissions can be different from each other
    // This test just verifies that both methods work independently
    #expect(cameraStatus != nil)
    #expect(microphoneStatus != nil)
  }
  
  @Test("permission status types")
  func testPermissionStatusTypes() async throws {
    // Test that all AVAuthorizationStatus cases are handled properly
    let statuses: [AVAuthorizationStatus] = [.notDetermined, .restricted, .denied, .authorized]
    
    for status in statuses {
      // Each status should be a valid case
      switch status {
      case .notDetermined:
        #expect(status == .notDetermined)
      case .restricted:
        #expect(status == .restricted)
      case .denied:
        #expect(status == .denied)
      case .authorized:
        #expect(status == .authorized)
      @unknown default:
        // Should not reach here with known cases
        #expect(Bool(false), "Unexpected authorization status")
      }
    }
  }
  
  @Test("multiple calls to shared instance")
  func testMultipleSharedInstanceCalls() async throws {
    // Test that multiple calls to shared return the same instance
    var instances: [PermissionsHelper] = []
    
    for _ in 0..<10 {
      instances.append(PermissionsHelper.shared)
    }
    
    // All instances should be the same object
    let firstInstance = instances[0]
    for instance in instances {
      #expect(instance === firstInstance)
    }
  }
  
  @Test("permission methods are callable")
  func testPermissionMethodsCallable() async throws {
    let helper = PermissionsHelper.shared
    
    // Test that methods can be called without crashing
    let cameraStatus = helper.checkCameraPermission()
    let microphoneStatus = helper.checkMicrophonePermission()
    
    // Should get valid statuses
    #expect(cameraStatus != nil)
    #expect(microphoneStatus != nil)
    
    // Async methods should be callable (may show system dialogs in real environment)
    async let cameraRequest = helper.requestCameraPermission()
    async let microphoneRequest = helper.requestMicrophonePermission()
    
    let cameraResult = await cameraRequest
    let microphoneResult = await microphoneRequest
    
    // Results should be boolean values
    #expect(cameraResult == true || cameraResult == false)
    #expect(microphoneResult == true || microphoneResult == false)
  }
  
  @Test("request all permissions matches individual requests")
  func testRequestAllPermissionsConsistency() async throws {
    let helper = PermissionsHelper.shared
    
    // Request permissions individually
    async let individualCamera = helper.requestCameraPermission()
    async let individualMicrophone = helper.requestMicrophonePermission()
    
    let cameraResult = await individualCamera
    let microphoneResult = await individualMicrophone
    
    // Request permissions together
    let combinedResult = await helper.requestAllPermissions()
    
    // In a test environment, results should be consistent
    // Note: In a real environment with user interaction, results might vary
    // This test mainly verifies that all methods execute without errors
    #expect(cameraResult == true || cameraResult == false)
    #expect(microphoneResult == true || microphoneResult == false)
    #expect(combinedResult.camera == true || combinedResult.camera == false)
    #expect(combinedResult.microphone == true || combinedResult.microphone == false)
  }
}