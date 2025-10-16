//
//  SceneKitView.swift
//  foreman
//
//  Created by Claude on 2025/10/14.
//

import SwiftUI
import SceneKit
import OSLog

struct SceneKitView: UIViewRepresentable {
  let model: ThreeDModel?
  let backgroundColor: Color
  let isInteractionEnabled: Bool
  
  @State private var sceneView = SCNView()
  private let logger = Logger(subsystem: "foreman", category: "SceneKitView")
  
  init(
    model: ThreeDModel? = nil,
    backgroundColor: Color = .black,
    isInteractionEnabled: Bool = true
  ) {
    self.model = model
    self.backgroundColor = backgroundColor
    self.isInteractionEnabled = isInteractionEnabled
  }
  
  func makeUIView(context: Context) -> SCNView {
    sceneView.backgroundColor = UIColor(backgroundColor)
    sceneView.allowsCameraControl = isInteractionEnabled
    sceneView.autoenablesDefaultLighting = true
    sceneView.antialiasingMode = .multisampling2X
    
    // Setup default scene
    let scene = SCNScene()
    sceneView.scene = scene
    
    // Setup default camera
    setupDefaultCamera(in: scene)
    
    // Load model if provided
    if let model = model {
      loadModel(model, into: scene)
    }
    
    logger.info("🎬 SceneKitView initialized with model: \(model?.name ?? "none")")
    
    return sceneView
  }
  
  func updateUIView(_ uiView: SCNView, context: Context) {
    guard let model = model else {
      // Clear scene if no model
      let emptyScene = SCNScene()
      setupDefaultCamera(in: emptyScene)
      uiView.scene = emptyScene
      return
    }
    
    // Check if we need to load a new model
    if uiView.scene?.rootNode.childNodes.isEmpty == true {
      loadModel(model, into: uiView.scene!)
    }
  }
  
  private func setupDefaultCamera(in scene: SCNScene, distance: Float = 3) {
    let cameraNode = SCNNode()
    cameraNode.camera = SCNCamera()
    cameraNode.position = SCNVector3(x: 0, y: 0, z: distance)
    scene.rootNode.addChildNode(cameraNode)
  }
  
  private func loadModel(_ model: ThreeDModel, into scene: SCNScene) {
    logger.info("🔄 Loading 3D model: \(model.name)")
    
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        // Load the .dae file
        let modelScene = try SCNScene(url: model.url, options: [
          SCNSceneSource.LoadingOption.animationImportPolicy: SCNSceneSource.AnimationImportPolicy.playRepeatedly,
          SCNSceneSource.LoadingOption.checkConsistency: true
        ])
        
        DispatchQueue.main.async {
          // Clear existing nodes
          scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
          
          // Add camera back
          setupDefaultCamera(in: scene)
          
          // Add model nodes
          for childNode in modelScene.rootNode.childNodes {
            scene.rootNode.addChildNode(childNode)
          }
          
          // Auto-center and scale the model
          centerAndScaleModel(scene: scene)
          
          logger.info("✅ 3D model loaded successfully: \(model.name)")
        }
      } catch {
        DispatchQueue.main.async {
          logger.error("❌ Failed to load 3D model \(model.name): \(error.localizedDescription)")
          
          // Show error placeholder
          showErrorPlaceholder(in: scene)
        }
      }
    }
  }
  
  private func centerAndScaleModel(scene: SCNScene) {
    // Create a container node for all model nodes (excluding camera)
    let modelContainer = SCNNode()

    // Move all non-camera nodes to container
    let nodesToMove = scene.rootNode.childNodes.filter { $0.camera == nil }
    for node in nodesToMove {
      node.removeFromParentNode()
      modelContainer.addChildNode(node)
    }

    // Add container to scene
    scene.rootNode.addChildNode(modelContainer)

    // Calculate bounding box of model container
    let (min, max) = modelContainer.boundingBox

    // Calculate center and size
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

    // Calculate maximum dimension for scaling
    let maxDimension = Swift.max(size.x, Swift.max(size.y, size.z))

    // Scale to fit nicely in view (target size of 2 units)
    let targetSize: Float = 2.0
    let scale = targetSize / maxDimension
    modelContainer.scale = SCNVector3(scale, scale, scale)

    // Center the model container
    modelContainer.position = SCNVector3(-center.x * scale, -center.y * scale, -center.z * scale)

    logger.info("🎯 Model centered and scaled - Size: \(maxDimension), Scale: \(scale)")
  }
  
  private func showErrorPlaceholder(in scene: SCNScene) {
    // Create a simple error indicator (red cube)
    let geometry = SCNBox(width: 0.5, height: 0.5, length: 0.5, chamferRadius: 0.1)
    geometry.firstMaterial?.diffuse.contents = UIColor.red
    
    let errorNode = SCNNode(geometry: geometry)
    errorNode.position = SCNVector3(0, 0, 0)
    
    scene.rootNode.addChildNode(errorNode)
    
    // Add rotation animation
    let rotation = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 3)
    let repeatRotation = SCNAction.repeatForever(rotation)
    errorNode.runAction(repeatRotation)
  }
}

#Preview("SceneKit View - Empty") {
  SceneKitView()
    .frame(width: 300, height: 200)
}

#Preview("SceneKit View - With Background") {
  SceneKitView(backgroundColor: .blue.opacity(0.1))
    .frame(width: 300, height: 200)
}

#Preview("SceneKit View - Base Telescope") {
  let previewModel: ThreeDModel? = {
    guard let url = Bundle.main.url(forResource: "base_telescope_old", withExtension: "dae") else {
      return nil
    }
    return ThreeDModel(
      name: "Base Telescope",
      url: url,
      fileSize: 1420680,
      createdDate: Date()
    )
  }()

  return SceneKitView(
    model: previewModel,
    backgroundColor: .black.opacity(0.8),
    isInteractionEnabled: true
  )
  .frame(width: 400, height: 300)
}
