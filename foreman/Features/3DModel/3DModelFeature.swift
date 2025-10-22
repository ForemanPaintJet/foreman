//
//  3DModelFeature.swift
//  foreman
//
//  Created by Claude on 2025/10/14.
//

import ComposableArchitecture
import OSLog
import Dependencies
import SwiftUI
import UniformTypeIdentifiers
import SceneKit

struct SceneWrapper: Equatable {
  let id = UUID()
  let scene: SCNScene

  static func == (lhs: SceneWrapper, rhs: SceneWrapper) -> Bool {
    lhs.id == rhs.id
  }
}

@Reducer
struct ThreeDModelFeature {
  @ObservableState
  struct State: Equatable, Identifiable {
    let id = UUID()
    var displayName: String
    var isMiniMode: Bool = true
    var currentModel: ThreeDModel?
    var loadingState: LoadingState = .idle
    var showFilePicker: Bool = false
    var recentModels: [ThreeDModel] = []
    var showFullScreen: Bool = false

    // Camera control state
    var backgroundColor: Color = .black.opacity(0.8)
    var isInteractionEnabled: Bool = true

    // Scene state
    var loadedScene: SceneWrapper?

    enum LoadingState: Equatable {
      case idle
      case loading
      case loaded
      case error(String)
    }
  }
  
  @CasePathable
  enum Action: Equatable, BindableAction, ComposableArchitecture.ViewAction {
    case view(ViewAction)
    case binding(BindingAction<State>)
    case _internal(InternalAction)
    case delegate(DelegateAction)
    
    @CasePathable
    enum ViewAction: Equatable {
      case task
      case teardown
      case setMiniMode(Bool)
      case showFilePicker(Bool)
      case showFullScreen(Bool)
      case loadBundleModel(String)
      case loadModel(ThreeDModel)
      case clearModel
      case refreshRecentModels
    }
    
    @CasePathable
    enum InternalAction: Equatable {
      case modelLoadingResult(Result<ThreeDModel, ThreeDAssetError>)
      case bundleModelLoadingResult(Result<ThreeDModel, ThreeDAssetError>)
      case sceneBuilt(SceneWrapper?)
    }
    
    @CasePathable
    enum DelegateAction: Equatable {
      case modelLoaded(ThreeDModel)
      case loadingStateChanged(State.LoadingState)
    }
  }
  
  private let logger = Logger(subsystem: "foreman", category: "3DModelFeature")
  
  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce(core)
  }
  
  func core(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .binding:
      return .none
      
    case .view(.task):
      logger.info("🎬 3DModelFeature: Starting task")
      return .send(.view(.refreshRecentModels))
      
    case .view(.teardown):
      logger.info("🛑 3DModelFeature: Tearing down")
      state.loadingState = .idle
      state.showFilePicker = false
      state.showFullScreen = false
      return .none
      
    case .view(.setMiniMode(let isMini)):
      state.isMiniMode = isMini
      logger.info("🔄 3DModelFeature: Mini mode set to \(isMini)")
      return .none
      
    case .view(.showFilePicker(let show)):
      state.showFilePicker = show
      return .none
      
    case .view(.showFullScreen(let show)):
      state.showFullScreen = show
      return .none
      
    case .view(.loadBundleModel(let filename)):
      state.loadingState = .loading
      logger.info("📦 3DModelFeature: Loading bundle model: \(filename)")
      
      return .run { send in
        @Dependency(\.threeDAssetClient) var assetClient
        let result: Result<ThreeDModel, ThreeDAssetError>
        do {
          let model = try await assetClient.loadBundleModel(filename)
          result = .success(model)
        } catch let error as ThreeDAssetError {
          result = .failure(error)
        } catch {
          result = .failure(.loadingFailed(error.localizedDescription))
        }
        await send(._internal(.bundleModelLoadingResult(result)))
      }
      
    case .view(.loadModel(let model)):
      state.loadingState = .loading
      state.currentModel = model
      logger.info("🔄 3DModelFeature: Loading model: \(model.name)")

      // Add to recent models if not already there
      if !state.recentModels.contains(where: { $0.id == model.id }) {
        state.recentModels.insert(model, at: 0)
        // Keep only last 5 models
        if state.recentModels.count > 5 {
          state.recentModels = Array(state.recentModels.prefix(5))
        }
      }

      // Build scene from model
      return buildScene(from: model)
      
    case .view(.clearModel):
      logger.info("🗑️ 3DModelFeature: Clearing current model")
      state.currentModel = nil
      state.loadedScene = nil
      state.loadingState = .idle
      return .send(.delegate(.loadingStateChanged(.idle)))
      
    case .view(.refreshRecentModels):
      // In a real implementation, this would load from persistent storage
      logger.info("🔄 3DModelFeature: Refreshing recent models")
      return .none
      
    case ._internal(.modelLoadingResult(.success(let model))):
      state.currentModel = model
      state.loadingState = .loaded
      logger.info("✅ 3DModelFeature: Model loaded successfully: \(model.name)")
      
      return .merge([
        .send(.delegate(.modelLoaded(model))),
        .send(.delegate(.loadingStateChanged(.loaded)))
      ])
      
    case ._internal(.modelLoadingResult(.failure(let error))):
      let errorMessage = error.localizedDescription
      state.loadingState = .error(errorMessage)
      logger.error("❌ 3DModelFeature: Model loading failed: \(errorMessage)")
      
      return .send(.delegate(.loadingStateChanged(.error(errorMessage))))
      
    case ._internal(.bundleModelLoadingResult(.success(let model))):
      state.currentModel = model
      state.loadingState = .loaded
      logger.info("✅ 3DModelFeature: Bundle model loaded successfully: \(model.name)")
      
      // Add to recent models
      if !state.recentModels.contains(where: { $0.id == model.id }) {
        state.recentModels.insert(model, at: 0)
        if state.recentModels.count > 5 {
          state.recentModels = Array(state.recentModels.prefix(5))
        }
      }
      
      return .merge([
        .send(.delegate(.modelLoaded(model))),
        .send(.delegate(.loadingStateChanged(.loaded)))
      ])
      
    case ._internal(.bundleModelLoadingResult(.failure(let error))):
      let errorMessage = error.localizedDescription
      state.loadingState = .error(errorMessage)
      logger.error("❌ 3DModelFeature: Bundle model loading failed: \(errorMessage)")

      return .send(.delegate(.loadingStateChanged(.error(errorMessage))))

    case ._internal(.sceneBuilt(let scene)):
      state.loadedScene = scene
      if let scene = scene {
        state.loadingState = .loaded
        logger.info("✅ 3DModelFeature: Scene built successfully")
        return .merge([
          .send(.delegate(.loadingStateChanged(.loaded)))
        ])
      } else {
        let errorMessage = "Failed to build scene"
        state.loadingState = .error(errorMessage)
        logger.error("❌ 3DModelFeature: Scene building failed")
        return .send(.delegate(.loadingStateChanged(.error(errorMessage))))
      }

    case .delegate:
      return .none
    }
  }

  // MARK: - Scene Building

  private func buildScene(from model: ThreeDModel) -> Effect<Action> {
    return .run { send in
      let scene = await Task.detached {
        Self.createScene(from: model)
      }.value

      await send(._internal(.sceneBuilt(scene)))
    }
  }

  static func createScene(from model: ThreeDModel) -> SceneWrapper? {
    let scene = SCNScene()

    // Setup camera
    let cameraNode = SCNNode()
    cameraNode.camera = SCNCamera()
    cameraNode.position = SCNVector3(x: 0, y: 0, z: 3)
    scene.rootNode.addChildNode(cameraNode)

    // Load model
    do {
      let modelScene = try SCNScene(url: model.url, options: [
        SCNSceneSource.LoadingOption.animationImportPolicy: SCNSceneSource.AnimationImportPolicy.playRepeatedly,
        SCNSceneSource.LoadingOption.checkConsistency: true
      ])

      // Add model nodes
      for childNode in modelScene.rootNode.childNodes {
        scene.rootNode.addChildNode(childNode)
      }

      // Center and scale model
      centerAndScaleModel(scene: scene)

      return SceneWrapper(scene: scene)
    } catch {
      Logger(subsystem: "foreman", category: "3DModelFeature")
        .error("❌ Failed to load 3D model: \(error.localizedDescription)")
      return nil
    }
  }

  static func centerAndScaleModel(scene: SCNScene) {
    let modelContainer = SCNNode()

    let nodesToMove = scene.rootNode.childNodes.filter { $0.camera == nil }
    for node in nodesToMove {
      node.removeFromParentNode()
      modelContainer.addChildNode(node)
    }

    scene.rootNode.addChildNode(modelContainer)

    let (min, max) = modelContainer.boundingBox

    let center = SCNVector3(
      x: (min.x + max.x) / 2,
      y: (min.y + max.y) / 2,
      z: (min.z + max.z) / 2
    )

    let size = SCNVector3(
      x: max.x - min.x,
      y: max.y - min.y,
      z: max.z - min.z
    )

    let maxDimension = Swift.max(size.x, Swift.max(size.y, size.z))
    let targetSize: Float = 2.0
    let scale = targetSize / maxDimension
    modelContainer.scale = SCNVector3(scale, scale, scale)
    modelContainer.position = SCNVector3(-center.x * scale, -center.y * scale, -center.z * scale)
  }
}
