//
//  3DModelRealityKitFeature.swift
//  foreman
//
//  Created by Claude on 2025/10/22.
//

import ComposableArchitecture
import OSLog
import Dependencies
import SwiftUI
import RealityKit

struct EntityWrapper: Equatable {
  let id = UUID()
  let entity: Entity

  static func == (lhs: EntityWrapper, rhs: EntityWrapper) -> Bool {
    lhs.id == rhs.id
  }
}

struct EntityInfo: Equatable, Identifiable {
  let id: UInt64
  let name: String
  let position: SIMD3<Float>
  let hasChildren: Bool

  init(from entity: Entity) {
    self.id = entity.id
    self.name = entity.name.isEmpty ? "Unnamed" : entity.name
    self.position = entity.position
    self.hasChildren = !entity.children.isEmpty
  }
}

@Reducer
struct ThreeDModelRealityKitFeature {
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

    // RealityKit specific state
    var loadedEntity: EntityWrapper?
    var selectedEntityId: UInt64?
    var availableEntities: [EntityInfo] = []

    // Camera control state
    var backgroundColor: Color = .black.opacity(0.8)
    var isInteractionEnabled: Bool = true

    enum LoadingState: Equatable {
      case idle
      case loading
      case loaded
      case error(String)
    }

    var selectedEntity: EntityInfo? {
      availableEntities.first { $0.id == selectedEntityId }
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
      case entityTapped(UInt64)
      case clearSelection
    }

    @CasePathable
    enum InternalAction: Equatable {
      case modelLoadingResult(Result<ThreeDModel, ThreeDAssetError>)
      case bundleModelLoadingResult(Result<ThreeDModel, ThreeDAssetError>)
      case entityBuilt(EntityWrapper?, [EntityInfo])
    }

    @CasePathable
    enum DelegateAction: Equatable {
      case modelLoaded(ThreeDModel)
      case loadingStateChanged(State.LoadingState)
      case entitySelected(EntityInfo?)
    }
  }

  private let logger = Logger(subsystem: "foreman", category: "3DModelRealityKitFeature")

  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce(core)
  }

  func core(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .binding:
      return .none

    case .view(.task):
      logger.info("🎬 3DModelRealityKitFeature: Starting task")
      return .send(.view(.refreshRecentModels))

    case .view(.teardown):
      logger.info("🛑 3DModelRealityKitFeature: Tearing down")
      state.loadingState = .idle
      state.showFilePicker = false
      state.showFullScreen = false
      return .none

    case .view(.setMiniMode(let isMini)):
      state.isMiniMode = isMini
      logger.info("🔄 3DModelRealityKitFeature: Mini mode set to \(isMini)")
      return .none

    case .view(.showFilePicker(let show)):
      state.showFilePicker = show
      return .none

    case .view(.showFullScreen(let show)):
      state.showFullScreen = show
      return .none

    case .view(.loadBundleModel(let filename)):
      state.loadingState = .loading
      logger.info("📦 3DModelRealityKitFeature: Loading bundle model: \(filename)")

      return .run { send in
        @Dependency(\.threeDAssetClient) var assetClient
        let result: Result<ThreeDModel, ThreeDAssetError>
        do {
          let model = try await assetClient.loadBundleModelUSDZ(filename)
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
      logger.info("🔄 3DModelRealityKitFeature: Loading model: \(model.name)")

      // Add to recent models if not already there
      if !state.recentModels.contains(where: { $0.id == model.id }) {
        state.recentModels.insert(model, at: 0)
        // Keep only last 5 models
        if state.recentModels.count > 5 {
          state.recentModels = Array(state.recentModels.prefix(5))
        }
      }

      // Build entity from model
      return buildEntity(from: model)

    case .view(.clearModel):
      logger.info("🗑️ 3DModelRealityKitFeature: Clearing current model")
      state.currentModel = nil
      state.loadedEntity = nil
      state.selectedEntityId = nil
      state.availableEntities = []
      state.loadingState = .idle
      return .send(.delegate(.loadingStateChanged(.idle)))

    case .view(.refreshRecentModels):
      logger.info("🔄 3DModelRealityKitFeature: Refreshing recent models")
      return .none

    case .view(.entityTapped(let entityId)):
      logger.info("👆 3DModelRealityKitFeature: Entity tapped: \(entityId)")
      state.selectedEntityId = entityId
      return .send(.delegate(.entitySelected(state.selectedEntity)))

    case .view(.clearSelection):
      logger.info("🔄 3DModelRealityKitFeature: Clearing selection")
      state.selectedEntityId = nil
      return .send(.delegate(.entitySelected(nil)))

    case ._internal(.modelLoadingResult(.success(let model))):
      state.currentModel = model
      state.loadingState = .loaded
      logger.info("✅ 3DModelRealityKitFeature: Model loaded successfully: \(model.name)")

      return .merge([
        .send(.delegate(.modelLoaded(model))),
        .send(.delegate(.loadingStateChanged(.loaded)))
      ])

    case ._internal(.modelLoadingResult(.failure(let error))):
      let errorMessage = error.localizedDescription
      state.loadingState = .error(errorMessage)
      logger.error("❌ 3DModelRealityKitFeature: Model loading failed: \(errorMessage)")

      return .send(.delegate(.loadingStateChanged(.error(errorMessage))))

    case ._internal(.bundleModelLoadingResult(.success(let model))):
      state.currentModel = model
      logger.info("✅ 3DModelRealityKitFeature: Bundle model loaded successfully: \(model.name)")

      // Add to recent models
      if !state.recentModels.contains(where: { $0.id == model.id }) {
        state.recentModels.insert(model, at: 0)
        if state.recentModels.count > 5 {
          state.recentModels = Array(state.recentModels.prefix(5))
        }
      }

      // Build entity from model
      return buildEntity(from: model)

    case ._internal(.bundleModelLoadingResult(.failure(let error))):
      let errorMessage = error.localizedDescription
      state.loadingState = .error(errorMessage)
      logger.error("❌ 3DModelRealityKitFeature: Bundle model loading failed: \(errorMessage)")

      return .send(.delegate(.loadingStateChanged(.error(errorMessage))))

    case ._internal(.entityBuilt(let entityWrapper, let entityInfos)):
      state.loadedEntity = entityWrapper
      state.availableEntities = entityInfos
      if let entityWrapper = entityWrapper {
        state.loadingState = .loaded
        logger.info("✅ 3DModelRealityKitFeature: Entity built successfully with \(entityInfos.count) interactive entities")
        return .send(.delegate(.loadingStateChanged(.loaded)))
      } else {
        let errorMessage = "Failed to build entity"
        state.loadingState = .error(errorMessage)
        logger.error("❌ 3DModelRealityKitFeature: Entity building failed")
        return .send(.delegate(.loadingStateChanged(.error(errorMessage))))
      }

    case .delegate:
      return .none
    }
  }

  // MARK: - Entity Building

  private func buildEntity(from model: ThreeDModel) -> Effect<Action> {
    return .run { send in
      let (entityWrapper, entityInfos) = await Task.detached {
        Self.createEntity(from: model)
      }.value

      await send(._internal(.entityBuilt(entityWrapper, entityInfos)))
    }
  }

  static func createEntity(from model: ThreeDModel) -> (EntityWrapper?, [EntityInfo]) {
    do {
      // Load entity from USDZ
      let entity = try Entity.load(contentsOf: model.url)

      // Configure entity for interaction
      configureEntityForInteraction(entity)

      // Collect all interactive entities
      let entityInfos = collectEntityInfo(from: entity)

      // Center and scale entity
//      centerAndScaleEntity(entity)

      return (EntityWrapper(entity: entity), entityInfos)
    } catch {
      Logger(subsystem: "foreman", category: "3DModelRealityKitFeature")
        .error("❌ Failed to load 3D model: \(error.localizedDescription)")
      return (nil, [])
    }
  }

  static func configureEntityForInteraction(_ entity: Entity) {
    let logger = Logger(subsystem: "foreman", category: "3DModelRealityKitFeature")

    // Recursively add collision and input target components to all entities
    for child in entity.children {
      configureEntityForInteraction(child)
    }

    // Add components if entity has a model component
    if entity.components.has(ModelComponent.self) {
      // Add collision component for hit testing
      let bounds = entity.visualBounds(relativeTo: nil)
      let size = bounds.extents

      // Ensure size is valid (not zero)
      let adjustedSize = SIMD3<Float>(
        size.x > 0 ? size.x : 0.1,
        size.y > 0 ? size.y : 0.1,
        size.z > 0 ? size.z : 0.1
      )

      let shape = ShapeResource.generateBox(size: adjustedSize)
      entity.components[CollisionComponent.self] = CollisionComponent(
        shapes: [shape],
        mode: .default,
        filter: .default
      )

      // Add input target component to receive gestures
      entity.components[InputTargetComponent.self] = InputTargetComponent(allowedInputTypes: .all)

      logger.info("🎯 Configured '\(entity.name)' - size: \(adjustedSize), hasCollision: \(entity.components.has(CollisionComponent.self)), hasInput: \(entity.components.has(InputTargetComponent.self))")
    }
  }

  static func collectEntityInfo(from entity: Entity) -> [EntityInfo] {
    var infos: [EntityInfo] = []

    // Add current entity if it has a model
    if entity.components.has(ModelComponent.self) {
      infos.append(EntityInfo(from: entity))
    }

    // Recursively collect from children
    for child in entity.children {
      infos.append(contentsOf: collectEntityInfo(from: child))
    }

    return infos
  }

  static func centerAndScaleEntity(_ entity: Entity) {
    // Get bounds
    let bounds = entity.visualBounds(relativeTo: nil)
    let center = bounds.center
    let extents = bounds.extents

    // Calculate max dimension for scaling
    let maxDimension = max(extents.x, max(extents.y, extents.z))

    // Scale to fit nicely (target size of 0.5 units)
    let targetSize: Float = 0.5
    let scale = targetSize / maxDimension
    entity.scale = [scale, scale, scale]

    // Center the entity
    entity.position = [-center.x * scale, -center.y * scale, -center.z * scale]
  }
}
