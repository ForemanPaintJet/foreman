//
//  3DModelFeatureTests.swift
//  foremanTests
//
//  Created by Claude on 2025/10/14.
//

import ComposableArchitecture
import XCTest
@testable import foreman

@MainActor
final class ThreeDModelFeatureTests: XCTestCase {
  
  func testInitialState() {
    let store = TestStore(initialState: ThreeDModelFeature.State()) {
      ThreeDModelFeature()
    }
    
    expectNoDifference(store.state.displayName, "3D Model Viewer")
    expectNoDifference(store.state.isMiniMode, true)
    expectNoDifference(store.state.currentModel, nil)
    expectNoDifference(store.state.loadingState, .idle)
    expectNoDifference(store.state.showFilePicker, false)
    expectNoDifference(store.state.recentModels, [])
  }
  
  func testTaskAction() async {
    let store = TestStore(initialState: ThreeDModelFeature.State()) {
      ThreeDModelFeature()
    }
    
    await store.send(\.view.task)
    await store.receive(\.view.refreshRecentModels)
  }
  
  func testSetMiniMode() async {
    let store = TestStore(initialState: ThreeDModelFeature.State()) {
      ThreeDModelFeature()
    }
    
    expectNoDifference(store.state.isMiniMode, true)
    
    await store.send(\.view.setMiniMode, false) {
      $0.isMiniMode = false
    }
    
    await store.send(\.view.setMiniMode, true) {
      $0.isMiniMode = true
    }
  }
  
  func testShowFilePicker() async {
    let store = TestStore(initialState: ThreeDModelFeature.State()) {
      ThreeDModelFeature()
    }
    
    expectNoDifference(store.state.showFilePicker, false)
    
    await store.send(\.view.showFilePicker, true) {
      $0.showFilePicker = true
    }
    
    await store.send(\.view.showFilePicker, false) {
      $0.showFilePicker = false
    }
  }
  
  func testShowFullScreen() async {
    let store = TestStore(initialState: ThreeDModelFeature.State()) {
      ThreeDModelFeature()
    }
    
    expectNoDifference(store.state.showFullScreen, false)
    
    await store.send(\.view.showFullScreen, true) {
      $0.showFullScreen = true
    }
    
    await store.send(\.view.showFullScreen, false) {
      $0.showFullScreen = false
    }
  }
  
  func testLoadModel() async {
    let testModel = ThreeDModel(
      name: "Test Model",
      url: URL(fileURLWithPath: "/test/path"),
      fileSize: 1024,
      createdDate: Date(timeIntervalSince1970: 0)
    )
    
    let store = TestStore(initialState: ThreeDModelFeature.State()) {
      ThreeDModelFeature()
    }
    
    await store.send(\.view.loadModel, testModel) {
      $0.currentModel = testModel
      $0.loadingState = .loaded
      $0.recentModels = [testModel]
    }
    
    await store.receive(\.delegate.modelLoaded, testModel)
    await store.receive(\.delegate.loadingStateChanged, .loaded)
  }
  
  func testLoadBundleModelSuccess() async {
    let testModel = ThreeDModel(
      name: "test_cube",
      url: URL(fileURLWithPath: "/bundle/test_cube.dae"),
      fileSize: 2048,
      createdDate: Date(timeIntervalSince1970: 0)
    )
    
    let store = TestStore(initialState: ThreeDModelFeature.State()) {
      ThreeDModelFeature()
    } withDependencies: {
      $0.threeDAssetClient.loadBundleModel = { _ in testModel }
    }
    
    await store.send(\.view.loadBundleModel, "test_cube") {
      $0.loadingState = .loading
    }
    
    await store.receive(\._internal.bundleModelLoadingResult, .success(testModel)) {
      $0.currentModel = testModel
      $0.loadingState = .loaded
      $0.recentModels = [testModel]
    }
    
    await store.receive(\.delegate.modelLoaded, testModel)
    await store.receive(\.delegate.loadingStateChanged, .loaded)
  }
  
  func testLoadBundleModelFailure() async {
    let error = ThreeDAssetError.fileNotFound
    
    let store = TestStore(initialState: ThreeDModelFeature.State()) {
      ThreeDModelFeature()
    } withDependencies: {
      $0.threeDAssetClient.loadBundleModel = { _ in throw error }
    }
    
    await store.send(\.view.loadBundleModel, "nonexistent") {
      $0.loadingState = .loading
    }
    
    await store.receive(\._internal.bundleModelLoadingResult, .failure(error)) {
      $0.loadingState = .error(error.localizedDescription)
    }
    
    await store.receive(\.delegate.loadingStateChanged, .error(error.localizedDescription))
  }
  
  func testClearModel() async {
    let testModel = ThreeDModel(
      name: "Test Model",
      url: URL(fileURLWithPath: "/test/path"),
      fileSize: 1024,
      createdDate: Date(timeIntervalSince1970: 0)
    )
    
    let store = TestStore(
      initialState: ThreeDModelFeature.State(
        displayName: "Test",
        isMiniMode: true
      )
    ) {
      ThreeDModelFeature()
    }
    
    // Load a model first
    await store.send(\.view.loadModel, testModel) {
      $0.currentModel = testModel
      $0.loadingState = .loaded
      $0.recentModels = [testModel]
    }
    await store.receive(\.delegate.modelLoaded, testModel)
    await store.receive(\.delegate.loadingStateChanged, .loaded)
    
    // Clear the model
    await store.send(\.view.clearModel) {
      $0.currentModel = nil
      $0.loadingState = .idle
    }
    await store.receive(\.delegate.loadingStateChanged, .idle)
  }
  
  func testTeardown() async {
    let store = TestStore(
      initialState: ThreeDModelFeature.State(
        displayName: "Test",
        isMiniMode: false
      )
    ) {
      ThreeDModelFeature()
    }
    
    // Set some state
    store.state.showFilePicker = true
    store.state.showFullScreen = true
    store.state.loadingState = .loading
    
    await store.send(\.view.teardown) {
      $0.loadingState = .idle
      $0.showFilePicker = false
      $0.showFullScreen = false
    }
  }
  
  func testRecentModelsLimit() async {
    let store = TestStore(initialState: ThreeDModelFeature.State()) {
      ThreeDModelFeature()
    }
    
    // Load 6 models to test the limit of 5
    for i in 1...6 {
      let model = ThreeDModel(
        name: "Model \(i)",
        url: URL(fileURLWithPath: "/test/model\(i).dae"),
        fileSize: Int64(i * 100),
        createdDate: Date(timeIntervalSince1970: TimeInterval(i))
      )
      
      await store.send(\.view.loadModel, model) {
        $0.currentModel = model
        $0.loadingState = .loaded
        // Only keep the last 5 models
        $0.recentModels = [model] + Array($0.recentModels.prefix(4))
      }
      await store.receive(\.delegate.modelLoaded, model)
      await store.receive(\.delegate.loadingStateChanged, .loaded)
    }
    
    // Verify we only have 5 models in recent list
    expectNoDifference(store.state.recentModels.count, 5)
    expectNoDifference(store.state.recentModels.first?.name, "Model 6")
  }
}