//
//  3DModelRealityKitView.swift
//  foreman
//
//  Created by Claude on 2025/10/22.
//

import ComposableArchitecture
import OSLog
import RealityKit
import SwiftUI
import UniformTypeIdentifiers

@ViewAction(for: ThreeDModelRealityKitFeature.self)
struct ThreeDModelRealityKitView: View {
  @Bindable var store: StoreOf<ThreeDModelRealityKitFeature>
  private let logger = Logger(subsystem: "foreman", category: "3DModelRealityKitView")
  @State private var rootEntity: Entity?

  var body: some View {
    let _ = Self._printChanges()
    Group {
      if store.isMiniMode {
        miniModeView
      } else {
        fullModeView
      }
    }
    .task { send(.task) }
    .fileImporter(
      isPresented: $store.showFilePicker.sending(\.view.showFilePicker),
      allowedContentTypes: [.usdz],
      onCompletion: handleFileImport
    )
    .sheet(isPresented: $store.showFullScreen.sending(\.view.showFullScreen)) {
      fullScreenView
    }
  }

  @ViewBuilder
  private var miniModeView: some View {
    RoundedRectangle(cornerRadius: 12)
      .fill(.ultraThinMaterial)
      .frame(height: 120)
      .overlay {
        if let model = store.currentModel {
          modelThumbnailView(model)
        } else {
          emptyStateView
        }
      }
      .overlay(alignment: .topLeading) {
        statusIndicator
      }
      .onTapGesture {
        if store.currentModel != nil {
          send(.showFullScreen(true))
        }
      }
  }

  @ViewBuilder
  private var fullModeView: some View {
    VStack(spacing: 16) {
      header

      Group {
        if let model = store.currentModel {
          modelDisplayView(model)
        } else {
          emptyStateView
        }
      }
      .frame(minHeight: 300)

      controlsView

      if let selectedEntity = store.selectedEntity {
        selectedEntityInfoView(selectedEntity)
      }
    }
    .padding()
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
  }

  @ViewBuilder
  private var fullScreenView: some View {
    NavigationStack {
      ZStack {
        store.backgroundColor
          .ignoresSafeArea()

        if let entityWrapper = store.loadedEntity {
          realityView(for: entityWrapper.entity)
        } else {
          emptyStateView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .navigationTitle("3D Model Viewer (RealityKit)")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Close") {
            send(.showFullScreen(false))
          }
        }

        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            Button("Import Model") {
              send(.showFilePicker(true))
            }

            if store.currentModel != nil {
              Button("Clear Selection") {
                send(.clearSelection)
              }

              Button("Clear Model", role: .destructive) {
                send(.clearModel)
              }
            }
          } label: {
            Image(systemName: "ellipsis.circle")
          }
        }
      }
      .safeAreaInset(edge: .bottom) {
        if let selectedEntity = store.selectedEntity {
          selectedEntityInfoCard(selectedEntity)
        }
      }
    }
  }

  @ViewBuilder
  private var header: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(store.displayName)
          .font(.headline)
          .foregroundStyle(.primary)

        if let model = store.currentModel {
          Text(model.name)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Spacer()

      statusIndicator
    }
  }

  @ViewBuilder
  private var statusIndicator: some View {
    Group {
      switch store.loadingState {
      case .idle:
        Image(systemName: "cube.transparent")
          .foregroundStyle(.secondary)

      case .loading:
        ProgressView()
          .scaleEffect(0.8)

      case .loaded:
        Image(systemName: "cube.fill")
          .foregroundStyle(.green)

      case .error:
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(.red)
      }
    }
    .frame(width: 24, height: 24)
  }

  @ViewBuilder
  private func modelThumbnailView(_ model: ThreeDModel) -> some View {
    Group {
      if let entityWrapper = store.loadedEntity {
        realityView(for: entityWrapper.entity, enableGestures: false)
      } else {
        Color.clear
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay {
      LinearGradient(
        colors: [.clear, .black.opacity(0.3)],
        startPoint: .top,
        endPoint: .bottom
      )
    }
    .overlay(alignment: .bottomLeading) {
      VStack(alignment: .leading, spacing: 2) {
        Text(model.name)
          .font(.caption.bold())
          .foregroundStyle(.white)

        Text(formatFileSize(model.fileSize))
          .font(.caption2)
          .foregroundStyle(.white.opacity(0.8))
      }
      .padding(8)
    }
  }

  @ViewBuilder
  private func modelDisplayView(_ model: ThreeDModel) -> some View {
    VStack(spacing: 12) {
      ZStack {
        store.backgroundColor

        if let entityWrapper = store.loadedEntity {
          realityView(for: entityWrapper.entity, enableGestures: true)
        } else {
          ProgressView()
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 12))

      HStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          Text("File Size")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(formatFileSize(model.fileSize))
            .font(.caption.bold())
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 4) {
          Text("Entities")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text("\(store.availableEntities.count)")
            .font(.caption.bold())
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 4) {
          Text("Created")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(model.createdDate, style: .date)
            .font(.caption.bold())
        }
      }
      .padding(.horizontal)
    }
  }

  @ViewBuilder
  private func realityView(for entity: Entity, enableGestures: Bool = true) -> some View {
    RealityView { content in
      // Clone the entity to avoid modifying the original
      let clonedEntity = entity.clone(recursive: true)

      // Setup camera
      let camera = PerspectiveCamera()
//      camera.camera.fieldOfViewInDegrees = 100
      camera.position = [0, 0, 0.5]
      camera.look(at: [0, 0, 0], from: camera.position, relativeTo: nil)
      content.add(camera)

      // Add primary directional light (key light from top-front)
      let keyLight = Entity()
      keyLight.components[DirectionalLightComponent.self] = DirectionalLightComponent(
        color: .white,
        intensity: 3000,
        isRealWorldProxy: false
      )
      keyLight.look(at: [0, 0, 0], from: [2, 3, 2], relativeTo: nil)
      content.add(keyLight)

      // Add fill light (softer light from opposite side)
      let fillLight = Entity()
      fillLight.components[DirectionalLightComponent.self] = DirectionalLightComponent(
        color: .white,
        intensity: 1500,
        isRealWorldProxy: false
      )
      fillLight.look(at: [0, 0, 0], from: [-2, 1, -2], relativeTo: nil)
      content.add(fillLight)

      // Add ambient light for overall illumination
      let ambientLight = Entity()
      ambientLight.components[DirectionalLightComponent.self] = DirectionalLightComponent(
        color: .white,
        intensity: 800,
        isRealWorldProxy: false
      )
      ambientLight.look(at: [0, 0, 0], from: [0, 1, 0], relativeTo: nil)
      content.add(ambientLight)

      // Add model
      clonedEntity.generateCollisionShapes(recursive: true)
      content.add(clonedEntity)

      // Reconfigure cloned entity for interaction (after adding to content)
      configureEntityForGestures(clonedEntity)

      // Store reference for gesture handling
      rootEntity = clonedEntity
      content.camera = .spatialTracking
    }
    .gesture(
      DragGesture(minimumDistance: 0)
        .onEnded { value in
          handleTap(at: value.location)
        }
    )
  }

  private func handleTap(at location: CGPoint) {
    guard let root = rootEntity else {
      logger.warning("⚠️ No root entity available for tap handling")
      return
    }

    // Find all entities with collision components recursively
    let tappedEntity = findTappedEntity(in: root, at: location)

    let tmp = location

    if let entity = tappedEntity {
      logger.info("👆 Entity tapped: \(entity.name) (ID: \(entity.id))")
      send(.entityTapped(entity.id))
    } else {
      logger.debug("👆 Tap at - no entity found")
    }
  }

  private func findTappedEntity(in entity: Entity, at location: CGPoint) -> Entity? {
    // Check if current entity has a model component and collision
    if entity.components.has(ModelComponent.self),
       entity.components.has(CollisionComponent.self)
    {
      // For simplicity, return the first valid entity found
      // In a more sophisticated implementation, you would do proper ray casting
      return entity
    }

    // Recursively check children
    for child in entity.children {
      if let found = findTappedEntity(in: child, at: location) {
        return found
      }
    }

    return nil
  }

  private func configureEntityForGestures(_ entity: Entity) {
    // Recursively configure all children
    for child in entity.children {
      configureEntityForGestures(child)
    }

    // Configure current entity if it has a model
    if entity.components.has(ModelComponent.self) {
      // Generate collision shape
      let bounds = entity.visualBounds(relativeTo: nil)
      let size = bounds.extents

      // Use a slightly larger box to ensure hits are detected
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

      // Add input target
      entity.components[InputTargetComponent.self] = InputTargetComponent(allowedInputTypes: .all)

      logger.debug("✅ Configured entity '\(entity.name)' for gestures - size: \(adjustedSize)")
    }
  }

  @ViewBuilder
  private var emptyStateView: some View {
    VStack(spacing: 16) {
      Image(systemName: "cube.transparent")
        .font(.system(size: 48))
        .foregroundStyle(.secondary)

      VStack(spacing: 8) {
        Text("No 3D Model")
          .font(.headline)
          .foregroundStyle(.primary)

        Text("Tap to import a .usdz file")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .contentShape(Rectangle())
    .onTapGesture {
      send(.showFilePicker(true))
    }
  }

  @ViewBuilder
  private var controlsView: some View {
    HStack(spacing: 16) {
      Button("Import Model") {
        send(.showFilePicker(true))
      }
      .buttonStyle(.bordered)

      if store.currentModel != nil {
        Button("Full Screen") {
          send(.showFullScreen(true))
        }
        .buttonStyle(.bordered)

        if store.selectedEntity != nil {
          Button("Clear Selection") {
            send(.clearSelection)
          }
          .buttonStyle(.bordered)
        }

        Button("Clear", role: .destructive) {
          send(.clearModel)
        }
        .buttonStyle(.bordered)
      }

      Spacer()
    }
  }

  @ViewBuilder
  private func selectedEntityInfoView(_ entity: EntityInfo) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Selected Entity")
          .font(.caption.bold())
          .foregroundStyle(.secondary)

        Spacer()

        Button {
          send(.clearSelection)
        } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }

      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text("Name:")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(entity.name)
            .font(.caption.bold())
        }

        HStack {
          Text("Position:")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(String(format: "(%.2f, %.2f, %.2f)", entity.position.x, entity.position.y, entity.position.z))
            .font(.caption.bold())
        }

        HStack {
          Text("Has Children:")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(entity.hasChildren ? "Yes" : "No")
            .font(.caption.bold())
        }
      }
    }
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
  }

  @ViewBuilder
  private func selectedEntityInfoCard(_ entity: EntityInfo) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Selected")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(entity.name)
            .font(.headline)
        }

        Spacer()

        Button {
          send(.clearSelection)
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.title3)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }

      HStack(spacing: 20) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Position")
            .font(.caption2)
            .foregroundStyle(.secondary)
          Text(String(format: "%.2f, %.2f, %.2f", entity.position.x, entity.position.y, entity.position.z))
            .font(.caption.bold())
        }

        VStack(alignment: .leading, spacing: 2) {
          Text("Children")
            .font(.caption2)
            .foregroundStyle(.secondary)
          Text(entity.hasChildren ? "Yes" : "No")
            .font(.caption.bold())
        }
      }
    }
    .padding()
    .background(.regularMaterial)
  }

  private func handleFileImport(_ result: Result<URL, Error>) {
    switch result {
    case .success(let url):
      logger.info("📁 File selected: \(url.lastPathComponent)")

      Task {
        do {
          @Dependency(\.threeDAssetClient) var assetClient
          let model = try await assetClient.loadModelUSDZ(url)
          await send(.loadModel(model))
        } catch {
          logger.error("❌ Failed to load selected file: \(error.localizedDescription)")
        }
      }

    case .failure(let error):
      logger.error("❌ File selection failed: \(error.localizedDescription)")
    }
  }

  private func formatFileSize(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
  }
}

#Preview("TestRealityKit") {
  TestRealityKit()
}

#Preview("RealityKit 3D Model View - Loaded") {
  let previewModel: ThreeDModel? = {
    guard let url = Bundle.main.url(forResource: "toy_biplane_realistic", withExtension: "usdz") else {
      return nil
    }
    return ThreeDModel(
      name: "Toy Biplane",
      url: url,
      fileSize: 1420680,
      createdDate: Date()
    )
  }()

  let (entityWrapper, entityInfos) = previewModel.flatMap {
    ThreeDModelRealityKitFeature.createEntity(from: $0)
  } ?? (nil, [])

  ThreeDModelRealityKitView(
    store: Store(
      initialState: ThreeDModelRealityKitFeature.State(
        displayName: "3D Model Viewer (RealityKit)",
        isMiniMode: false,
        currentModel: previewModel,
        loadingState: .loaded,
        loadedEntity: entityWrapper,
        availableEntities: entityInfos
      )
    ) {
      ThreeDModelRealityKitFeature()
    }
  )
  .padding()
  .frame(width: 400, height: 700)
}

#Preview("RealityKit 3D Model View - Mini Mode") {
  ThreeDModelRealityKitView(
    store: Store(
      initialState: ThreeDModelRealityKitFeature.State(
        displayName: "3D Model Viewer (RealityKit)",
        isMiniMode: true
      )
    ) {
      ThreeDModelRealityKitFeature()
    }
  )
  .padding()
  .frame(width: 300)
}

#Preview("RealityKit 3D Model View - Full Mode Empty") {
  ThreeDModelRealityKitView(
    store: Store(
      initialState: ThreeDModelRealityKitFeature.State(
        displayName: "3D Model Viewer (RealityKit)",
        isMiniMode: false
      )
    ) {
      ThreeDModelRealityKitFeature()
    }
  )
  .padding()
  .frame(width: 400, height: 600)
}

struct TestRealityKit: View {
    @State private var rotationY: Float = 0.0
    @State private var scale: Float = 1.0
    
    let box = ModelEntity(mesh: .generateBox(size: 0.25))
    let group = Entity()
    
    let ratio: Float = 0.005 // 旋轉靈敏度
    
    var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // 水平拖曳 → Y 軸旋轉
                rotationY += Float(value.translation.width) * ratio
                group.orientation = simd_quatf(angle: rotationY, axis: [0,1,0])
            }
    }
    
    var pinch: some Gesture {
        MagnificationGesture()
            .onChanged { mag in
                // 縮放限制在 0.5 ~ 2.0
                scale = min(max(Float(mag), 0.5), 2.0)
                group.scale = SIMD3(repeating: scale)
            }
    }
    
    var body: some View {
        RealityView { rvc in
            // 把 box 加入 group，再加到場景
            let boxAnchor = try! Entity.load(named: "toy_biplane_realistic") // MyModel.usdz 放在專案資源
            group.addChild(boxAnchor)
//            group.addChild(box)
            rvc.add(group)
        }
        // 同時支持拖曳旋轉 + 捏合縮放
        .gesture(drag.simultaneously(with: pinch))
    }
}
