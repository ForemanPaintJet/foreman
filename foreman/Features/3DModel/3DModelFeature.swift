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
    
    enum LoadingState: Equatable {
      case idle
      case loading
      case loaded
      case error(String)
    }
    
    init(displayName: String = "3D Model Viewer", isMiniMode: Bool = true) {
      self.displayName = displayName
      self.isMiniMode = isMiniMode
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
        let result = await Result {
          try await assetClient.loadBundleModel(filename)
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
      
      state.loadingState = .loaded
      return .merge([
        .send(.delegate(.modelLoaded(model))),
        .send(.delegate(.loadingStateChanged(.loaded)))
      ])
      
    case .view(.clearModel):
      logger.info("🗑️ 3DModelFeature: Clearing current model")
      state.currentModel = nil
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
      
    case .delegate:
      return .none
    }
  }
}