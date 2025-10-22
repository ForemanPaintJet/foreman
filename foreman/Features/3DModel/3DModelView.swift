//
//  3DModelView.swift
//  foreman
//
//  Created by Claude on 2025/10/14.
//

import SwiftUI
import ComposableArchitecture
import UniformTypeIdentifiers
import OSLog
import SceneKit

@ViewAction(for: ThreeDModelFeature.self)
struct ThreeDModelView: View {
  @Bindable var store: StoreOf<ThreeDModelFeature>
  private let logger = Logger(subsystem: "foreman", category: "3DModelView")
  
  var body: some View {
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
      allowedContentTypes: [UTType(filenameExtension: "dae") ?? UTType.data],
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

        if let sceneWrapper = store.loadedScene {
          SceneView(
            scene: sceneWrapper.scene,
            pointOfView: nil,
            options: store.isInteractionEnabled ? [.allowsCameraControl, .autoenablesDefaultLighting] : [.autoenablesDefaultLighting],
            preferredFramesPerSecond: 60,
            antialiasingMode: .multisampling2X,
            delegate: nil,
            technique: nil
          )
        } else {
          emptyStateView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .navigationTitle("3D Model Viewer")
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
              Button("Clear Model", role: .destructive) {
                send(.clearModel)
              }
            }
          } label: {
            Image(systemName: "ellipsis.circle")
          }
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
      if let sceneWrapper = store.loadedScene {
        SceneView(
          scene: sceneWrapper.scene,
          pointOfView: nil,
          options: [.autoenablesDefaultLighting],
          preferredFramesPerSecond: 30,
          antialiasingMode: .multisampling2X,
          delegate: nil,
          technique: nil
        )
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
          .ignoresSafeArea()

        if let sceneWrapper = store.loadedScene {
          SceneView(
            scene: sceneWrapper.scene,
            pointOfView: nil,
            options: store.isInteractionEnabled ? [.allowsCameraControl, .autoenablesDefaultLighting] : [.autoenablesDefaultLighting],
            preferredFramesPerSecond: 60,
            antialiasingMode: .multisampling2X,
            delegate: nil,
            technique: nil
          )
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
  private var emptyStateView: some View {
    VStack(spacing: 16) {
      Image(systemName: "cube.transparent")
        .font(.system(size: 48))
        .foregroundStyle(.secondary)
      
      VStack(spacing: 8) {
        Text("No 3D Model")
          .font(.headline)
          .foregroundStyle(.primary)
        
        Text("Tap to import a .dae file")
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
        
        Button("Clear", role: .destructive) {
          send(.clearModel)
        }
        .buttonStyle(.bordered)
      }
      
      Spacer()
    }
  }
  
  private func handleFileImport(_ result: Result<URL, Error>) {
    switch result {
    case .success(let url):
      logger.info("📁 File selected: \(url.lastPathComponent)")
      
      // Create ThreeDModel from selected URL
      Task {
        do {
          @Dependency(\.threeDAssetClient) var assetClient
          let model = try await assetClient.loadModel(url)
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

#Preview("3D Model View") {
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

  ThreeDModelView(
    store: Store(
      initialState: ThreeDModelFeature.State(
        displayName: "3D Model Viewer",
        isMiniMode: false,
        currentModel: previewModel,
        loadingState: .loaded,
        loadedScene: previewModel.flatMap { ThreeDModelFeature.createScene(from: $0) }
      )
    ) {
      ThreeDModelFeature()
    }
  )
  .padding()
  .frame(width: 400, height: 600)
}

#Preview("3D Model View - Mini Mode") {
  ThreeDModelView(
    store: Store(
      initialState: ThreeDModelFeature.State(
        displayName: "3D Model Viewer",
        isMiniMode: true
      )
    ) {
      ThreeDModelFeature()
    }
  )
  .padding()
  .frame(width: 300)
}

#Preview("3D Model View - Full Mode") {
  ThreeDModelView(
    store: Store(
      initialState: ThreeDModelFeature.State(
        displayName: "3D Model Viewer",
        isMiniMode: false
      )
    ) {
      ThreeDModelFeature()
    }
  )
  .padding()
  .frame(width: 400, height: 600)
}
