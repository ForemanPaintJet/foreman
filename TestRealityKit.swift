//
//  TestRealityKit.swift
//  foreman
//
//  Created by Jed Lu on 2025/10/27.
//

import RealityKit
import SwiftUI

struct TestRealityKit: View {
  @State private var rotationX: Float = 0.0
  @State private var rotationY: Float = 0.0
  @State private var scale: Float = 1.0
  @State private var currentScale: Float = 1.0
  let group = AnchorEntity()
  @State private var biplane: Entity?

  // 動畫控制
  @State private var availableAnimations: [AnimationResource] = []
  @State private var animationNames: [String] = []
  @State private var selectedAnimation: String = ""
  @State private var isPlaying: Bool = false

  // 點擊檢測
  @State private var tappedEntity: Entity?
  @State private var tapCoordinates: SIMD3<Float>?
  @State private var highlightedEntities: Set<Entity> = []

  // 按壓-釋放檢測
  @State private var pressedEntity: Entity?
  @State private var hasHighlightedOnPress: Bool = false

  // 物件尺寸資訊
  @State private var modelOriginalSize: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
  @State private var boundingBoxSizeOriginal: SIMD3<Float> = SIMD3<Float>(0, 0, 0)

  // RealityView content 參考（用於投影計算）
  @State private var realityViewContent: RealityViewCameraContent?
  @State private var viewSize: CGSize = .zero

  // UI 控制
  @State private var showBoundingBoxInfo: Bool = false

  // 旋轉靈敏度
  let ratio: Float = 0.001

  // 計算屬性：將弧度轉換為度數
  private var rotationXDegrees: Float {
    rotationX * 180 / .pi
  }

  private var rotationYDegrees: Float {
    rotationY * 180 / .pi
  }

  // 計算總旋轉角度（從 quaternion）
  private var totalRotationAngle: Float {
    let quat = group.orientation
    return 2 * acos(min(1.0, abs(quat.real)))
  }

  private var totalRotationDegrees: Float {
    totalRotationAngle * 180 / .pi
  }

  // 計算當前實際尺寸（考慮用戶手動縮放）
  private var currentActualSize: SIMD3<Float> {
    SIMD3<Float>(
      modelOriginalSize.x * scale,
      modelOriginalSize.y * scale,
      modelOriginalSize.z * scale
    )
  }

  // 計算當前邊界框尺寸（考慮用戶手動縮放）
  private var boundingBoxSize: SIMD3<Float> {
    SIMD3<Float>(
      boundingBoxSizeOriginal.x * scale,
      boundingBoxSizeOriginal.y * scale,
      boundingBoxSizeOriginal.z * scale
    )
  }

  // 計算 bounding box 的 8 個角點（世界座標）
  private func getBoundingBoxCorners() -> [SIMD3<Float>] {
    let halfSize = boundingBoxSize / 2
    let center = group.position

    return [
      center + SIMD3<Float>(-halfSize.x, -halfSize.y, -halfSize.z),  // 左下後
      center + SIMD3<Float>(halfSize.x, -halfSize.y, -halfSize.z),   // 右下後
      center + SIMD3<Float>(-halfSize.x, halfSize.y, -halfSize.z),   // 左上後
      center + SIMD3<Float>(halfSize.x, halfSize.y, -halfSize.z),    // 右上後
      center + SIMD3<Float>(-halfSize.x, -halfSize.y, halfSize.z),   // 左下前
      center + SIMD3<Float>(halfSize.x, -halfSize.y, halfSize.z),    // 右下前
      center + SIMD3<Float>(-halfSize.x, halfSize.y, halfSize.z),    // 左上前
      center + SIMD3<Float>(halfSize.x, halfSize.y, halfSize.z)      // 右上前
    ]
  }

  // 投影資訊結構
  struct ProjectionInfo: Identifiable {
    let id = UUID()
    let cornerIndex: Int
    let corner3D: SIMD3<Float>
    let projected2D: CGPoint?
    let isOutOfBounds: Bool
  }

  // 取得所有角點的投影資訊
  private var cornerProjections: [ProjectionInfo] {
    guard let content = realityViewContent, viewSize != .zero else {
      return []
    }

    let corners = getBoundingBoxCorners()

    // 計算投影範圍
    let projectedPoints = corners.compactMap { content.project(point: $0, to: .local) }
    guard !projectedPoints.isEmpty else {
      return corners.enumerated().map { index, corner in
        ProjectionInfo(cornerIndex: index, corner3D: corner, projected2D: nil, isOutOfBounds: true)
      }
    }

    let xValues = projectedPoints.map { $0.x }
    let yValues = projectedPoints.map { $0.y }
    let minX = xValues.min() ?? 0
    let maxX = xValues.max() ?? 0
    let minY = yValues.min() ?? 0
    let maxY = yValues.max() ?? 0

    let projectedWidth = maxX - minX
    let projectedHeight = maxY - minY

    // 計算投影中心
    let projectedCenterX = (minX + maxX) / 2
    let projectedCenterY = (minY + maxY) / 2

    // 螢幕中心
    let screenCenterX = viewSize.width / 2
    let screenCenterY = viewSize.height / 2

    // 判斷是否超出：物件投影的最長邊超過螢幕對應維度
    let longestProjectedEdge = max(projectedWidth, projectedHeight)
    let correspondingScreenSize = projectedWidth > projectedHeight ? viewSize.width : viewSize.height
    let isOut = longestProjectedEdge > correspondingScreenSize

    return corners.enumerated().map { index, corner in
      let projected = content.project(point: corner, to: .local)
      return ProjectionInfo(
        cornerIndex: index,
        corner3D: corner,
        projected2D: projected,
        isOutOfBounds: isOut  // 所有角點共享同一個判斷結果
      )
    }
  }

  // 檢查 bounding box 是否超出螢幕範圍
  private var isOutOfScreen: Bool {
    guard !cornerProjections.isEmpty else { return false }
    return cornerProjections[0].isOutOfBounds  // 所有角點的判斷結果相同
  }

  // 計算投影後的螢幕尺寸（像素）
  private var projectedScreenSize: CGSize {
    let projectedPoints = cornerProjections.compactMap { $0.projected2D }
    guard !projectedPoints.isEmpty else {
      return .zero
    }

    let xValues = projectedPoints.map { $0.x }
    let yValues = projectedPoints.map { $0.y }

    let minX = xValues.min() ?? 0
    let maxX = xValues.max() ?? 0
    let minY = yValues.min() ?? 0
    let maxY = yValues.max() ?? 0

    return CGSize(
      width: CGFloat(maxX - minX),
      height: CGFloat(maxY - minY)
    )
  }

  var drag: some Gesture {
    DragGesture(minimumDistance: 10)
      .onChanged { value in
        // 水平拖曳 → Y 軸旋轉（左右旋轉）- 無限制 0~360度
        rotationY += Float(value.translation.width) * ratio

        // 垂直拖曳 → X 軸旋轉（上下旋轉）
        let newRotationX = rotationX + Float(value.translation.height) * ratio
        // 限制 X 軸旋轉在 -π/4~π/4 弧度（-45~45度），避免看到底部
        rotationX = max(-Float.pi / 4, min(Float.pi / 4, newRotationX))
        
        
        // 組合多軸旋轉
        let rotationQuatX = simd_quatf(angle: rotationX, axis: [1, 0, 0])
        let rotationQuatY = simd_quatf(angle: rotationY, axis: [0, 1, 0])
        
        // 先繞 Y 軸旋轉，再繞 X 軸旋轉
        group.orientation = rotationQuatY
      }.onEnded { _ in
        handleEntityRelease()
      }
  }

  var tap: some Gesture {
    DragGesture(minimumDistance: 0)
      .targetedToAnyEntity()
      .onChanged { value in
        // 只在第一次按下時高亮顯示
        if !hasHighlightedOnPress {
          handleEntityPress(value.entity)
        }
      }
  }

  var backgroundTap: some Gesture {
    TapGesture()
      .onEnded { _ in
        // 點擊空白處
      }
  }

  var pinch: some Gesture {
    MagnificationGesture()
      .onChanged { mag in
        print("Pinch detected: \(mag)")
        let newScale = currentScale * Float(mag)
        scale = min(max(newScale, 0.1), 5.0)
        print("New scale: \(scale)")
        group.scale = SIMD3(repeating: scale)
      }
      .onEnded { _ in
        print("Pinch ended, final scale: \(scale)")
        currentScale = scale
      }
  }

  private func setupAnimations() {
    guard let biplane else { return }

    // 查找可用動畫
    let animations = biplane.availableAnimations
    print("模型可用動畫數量：\(animations.count)")

    availableAnimations = animations
    animationNames = animations.map { $0.name ?? "無名動畫" }

    for anim in animations {
      print("動畫名稱：\(anim.name ?? "無名")")
    }

    // 設定預設選中的動畫
    if !animationNames.isEmpty {
      selectedAnimation = animationNames[0]
    }
  }

  // 動畫控制函數
  private func playAnimation() {
    guard let biplane,
          let animationIndex = animationNames.firstIndex(of: selectedAnimation),
          animationIndex < availableAnimations.count
    else {
      print("無法播放動畫：\(selectedAnimation)")
      return
    }

    let animation = availableAnimations[animationIndex]
    biplane.playAnimation(animation.repeat())
    isPlaying = true
    print("播放動畫：\(selectedAnimation)")
  }

  private func stopAnimation() {
    guard let biplane else { return }
    biplane.stopAllAnimations()
    isPlaying = false
    print("停止所有動畫")
  }

  private func playAnimationByName(_ name: String) {
    selectedAnimation = name
    playAnimation()
  }

  private func printEntityHierarchy(_ entity: Entity, depth: Int) {
    let indent = String(repeating: "  ", count: depth)
    let hasModel = entity.components.has(ModelComponent.self) ? " [Model]" : ""
    let hasCollision = entity.components.has(CollisionComponent.self) ? " [Collision]" : ""
    let childCount = entity.children.count > 0 ? " (\(entity.children.count) children)" : ""

    print("\(indent)- \(entity.name.isEmpty ? "<unnamed>" : entity.name)\(hasModel)\(hasCollision)\(childCount)")
    print("\(indent)  ID: \(entity.id)")

    for child in entity.children {
      printEntityHierarchy(child, depth: depth + 1)
    }
  }

  private func printDetailedModelInfo() {
    guard let biplane else {
      print("❌ 沒有載入的模型")
      return
    }

    print("🔍 ===== 完整模型結構分析 =====")
    printEntityHierarchy(biplane, depth: 0)
    print("🔍 ===== 結構分析完成 =====")

    // 尋找所有有 ModelComponent 的 entity
    var modelEntities: [Entity] = []
    findAllModelEntities(in: biplane, results: &modelEntities)

    print("\n📦 發現 \(modelEntities.count) 個有 ModelComponent 的實體:")
    for (index, entity) in modelEntities.enumerated() {
      print("  [\(index)] \(entity.name.isEmpty ? "<unnamed>" : entity.name) - ID: \(entity.id)")
    }
  }

  private func findAllModelEntities(in entity: Entity, results: inout [Entity]) {
    if entity.components.has(ModelComponent.self) {
      results.append(entity)
    }

    for child in entity.children {
      findAllModelEntities(in: child, results: &results)
    }
  }

  private func handleEntityPress(_ entity: Entity) {
    let entityPath = getEntityPath(entity)
    print("👇 按下實體: \(entity.name.isEmpty ? "<unnamed>" : entity.name)")
    print("🔗 實體路徑: \(entityPath)")
    print("🆔 實體ID: \(entity.id)")
    print("📍 座標: \(entity.position(relativeTo: nil))")

    // 高亮顯示按下的實體
    highlightEntity(entity)
    pressedEntity = entity
    hasHighlightedOnPress = true

    tappedEntity = entity
    tapCoordinates = entity.position(relativeTo: nil)

    // 顯示所有子實體
    print("👶 子實體數量: \(entity.children.count)")
    for (index, child) in entity.children.enumerated() {
      print("  [\(index)] \(child.name.isEmpty ? "<unnamed>" : child.name)")
    }
  }

  private func handleEntityRelease() {
    if let entity = pressedEntity {
      print("👆 釋放實體: \(entity.name.isEmpty ? "<unnamed>" : entity.name)")
      resetEntityColor(entity)
    }
    pressedEntity = nil
    hasHighlightedOnPress = false
  }

  private func getEntityPath(_ entity: Entity) -> String {
    var path: [String] = []
    var current: Entity? = entity

    while let entity = current {
      let name = entity.name.isEmpty ? "<unnamed>" : entity.name
      path.insert(name, at: 0)
      current = entity.parent
    }

    return path.joined(separator: " → ")
  }

  private func createAxisLines() {
    let axisLength: Float = 0.2
    let axisThickness: Float = 0.005

    // X 軸（紅色）
    let xAxisMesh = MeshResource.generateBox(size: SIMD3<Float>(axisLength, axisThickness, axisThickness))
    var xAxisMaterial = SimpleMaterial()
    xAxisMaterial.color = .init(tint: .red, texture: nil)
    xAxisMaterial.metallic = 0.0
    xAxisMaterial.roughness = 1.0
    let xAxis = ModelEntity(mesh: xAxisMesh, materials: [xAxisMaterial])
    xAxis.name = "X軸"
    xAxis.position = SIMD3<Float>(axisLength / 2, 0, 0)

    // Y 軸（綠色）
    let yAxisMesh = MeshResource.generateBox(size: SIMD3<Float>(axisThickness, axisLength, axisThickness))
    var yAxisMaterial = SimpleMaterial()
    yAxisMaterial.color = .init(tint: .green, texture: nil)
    yAxisMaterial.metallic = 0.0
    yAxisMaterial.roughness = 1.0
    let yAxis = ModelEntity(mesh: yAxisMesh, materials: [yAxisMaterial])
    yAxis.name = "Y軸"
    yAxis.position = SIMD3<Float>(0, axisLength / 2, 0)

    // Z 軸（藍色）
    let zAxisMesh = MeshResource.generateBox(size: SIMD3<Float>(axisThickness, axisThickness, axisLength))
    var zAxisMaterial = SimpleMaterial()
    zAxisMaterial.color = .init(tint: .blue, texture: nil)
    zAxisMaterial.metallic = 0.0
    zAxisMaterial.roughness = 1.0
    let zAxis = ModelEntity(mesh: zAxisMesh, materials: [zAxisMaterial])
    zAxis.name = "Z軸"
    zAxis.position = SIMD3<Float>(0, 0, axisLength / 2)

    // 創建一個容器來放置軸線，放在左下角偏移位置
    let axisContainer = Entity()
    axisContainer.addChild(xAxis)
    axisContainer.addChild(yAxis)
    axisContainer.addChild(zAxis)

    // 放在左下角，不干擾主模型
    axisContainer.position = SIMD3<Float>(-0.4, -0.3, 0)

    group.addChild(axisContainer)

    print("✅ 已創建 3D 軸線（左下角）：")
    print("   🔴 X 軸（紅色）- 向右")
    print("   🟢 Y 軸（綠色）- 向上")
    print("   🔵 Z 軸（藍色）- 向前")
    print("   📍 位置: (-0.4, -0.3, 0)")
  }

  private func configureInputTarget(_ entity: Entity) {
    // 為所有有 CollisionComponent 的實體添加 InputTargetComponent
    if entity.components.has(CollisionComponent.self) {
      entity.components[InputTargetComponent.self] = InputTargetComponent(allowedInputTypes: .all)
      print("✅ 已為實體 '\(entity.name.isEmpty ? "<unnamed>" : entity.name)' 添加 InputTargetComponent")
    }

    for child in entity.children {
      configureInputTarget(child)
    }
  }

  private func highlightEntity(_ entity: Entity) {
    guard entity.components.has(ModelComponent.self) else { return }
    guard var modelComponent = entity.components[ModelComponent.self] else { return }

    // 使用固定的藍色來高亮顯示
    let color = UIColor.systemBlue

    // 創建高亮材質
    var material = SimpleMaterial()
    material.color = .init(tint: color, texture: nil)
    material.metallic = 0.3
    material.roughness = 0.5

    // 應用材質
    modelComponent.materials = [material]
    entity.components[ModelComponent.self] = modelComponent

    // 記錄已高亮的實體
    highlightedEntities.insert(entity)

    print("🎨 高亮顯示組件 '\(entity.name.isEmpty ? "<unnamed>" : entity.name)' - 顏色: 藍色")
  }
  
  private func resetEntityColor(_ entity: Entity) {
    guard entity.components.has(ModelComponent.self) else { return }
    guard var modelComponent = entity.components[ModelComponent.self] else { return }

    // 恢復到原始材質（移除顏色覆蓋）
    var material = SimpleMaterial()
    material.color = .init(tint: .white, texture: nil)
    material.metallic = 0.1
    material.roughness = 0.9

    modelComponent.materials = [material]
    entity.components[ModelComponent.self] = modelComponent

    highlightedEntities.remove(entity)

    print("🔄 重置組件顏色 '\(entity.name.isEmpty ? "<unnamed>" : entity.name)'")
  }

  private func calculateOptimalScale(for entity: Entity) -> Float {
    // 獲取模型的視覺邊界
    let bounds = entity.visualBounds(relativeTo: nil)
    let modelSize = bounds.extents

    // 保存原始尺寸
    modelOriginalSize = modelSize

    print("📏 模型原始尺寸: \(String(format: "(%.3f, %.3f, %.3f)", modelSize.x, modelSize.y, modelSize.z))")

    // 目標顯示尺寸（單位：公尺，在 RealityKit 中）
    // 這個值決定模型在視窗中的大小，可以根據需求調整
    // 對於 RealityView，建議在 0.3 ~ 0.8 之間以確保不超出螢幕
    let targetSize: Float = 0.6 // 建議在 0.3 ~ 0.8 之間

    // 找出模型最大的維度（考慮寬度和高度，深度影響較小）
    let maxDimension = max(modelSize.x, max(modelSize.y, modelSize.z))

    // 計算縮放比例
    let optimalScale = targetSize / maxDimension

    // 計算縮放後的實際尺寸
    let scaledSize = SIMD3<Float>(
      modelSize.x * optimalScale,
      modelSize.y * optimalScale,
      modelSize.z * optimalScale
    )

    print("📐 計算出的最佳縮放比例: \(String(format: "%.4f", optimalScale))")
    print("📦 縮放後的實際尺寸: \(String(format: "(%.3f, %.3f, %.3f)", scaledSize.x, scaledSize.y, scaledSize.z))")
    print("📊 寬度: \(String(format: "%.3f", scaledSize.x))m, 高度: \(String(format: "%.3f", scaledSize.y))m, 深度: \(String(format: "%.3f", scaledSize.z))m")

    // 檢查是否超出建議範圍
    if scaledSize.x > 1.0 || scaledSize.y > 1.0 {
      print("⚠️ 警告: 模型可能超出螢幕範圍！")
    } else if scaledSize.x < 0.2 || scaledSize.y < 0.2 {
      print("⚠️ 警告: 模型可能太小！")
    } else {
      print("✅ 模型尺寸在合理範圍內")
    }

    return optimalScale
  }

  private func createWireframeBoundingBox(for entity: Entity) -> Entity? {
    // 跳過已經是邊界框的實體
    if entity.name.hasPrefix("BoundingBox_") {
      return nil
    }

    // 獲取實體的視覺邊界
    let bounds = entity.visualBounds(relativeTo: entity)
    let size = bounds.extents

    // 如果尺寸太小或為零，跳過
    if size.x < 0.001 && size.y < 0.001 && size.z < 0.001 {
      return nil
    }

    // 確保尺寸有效(避免零尺寸)
    let adjustedSize = SIMD3<Float>(
      size.x > 0.001 ? size.x : 0.01,
      size.y > 0.001 ? size.y : 0.01,
      size.z > 0.001 ? size.z : 0.01
    )

    // 創建邊界框容器
    let boundingBoxContainer = Entity()
    boundingBoxContainer.name = "BoundingBox_\(entity.name.isEmpty ? "unnamed" : entity.name)"

    // 線條粗細
    let lineThickness: Float = 0.003

    // 創建線框材質（藍色，半透明）
    var lineMaterial = SimpleMaterial()
    lineMaterial.color = .init(tint: .blue.withAlphaComponent(0.6), texture: nil)
    lineMaterial.metallic = 0.0
    lineMaterial.roughness = 1.0

    // 創建 12 條邊線（立方體有 12 條邊）
    // 4 條底邊
    let edges: [(start: SIMD3<Float>, end: SIMD3<Float>)] = [
      // 底面 4 條邊
      (SIMD3(-adjustedSize.x/2, -adjustedSize.y/2, -adjustedSize.z/2), SIMD3(adjustedSize.x/2, -adjustedSize.y/2, -adjustedSize.z/2)),
      (SIMD3(adjustedSize.x/2, -adjustedSize.y/2, -adjustedSize.z/2), SIMD3(adjustedSize.x/2, -adjustedSize.y/2, adjustedSize.z/2)),
      (SIMD3(adjustedSize.x/2, -adjustedSize.y/2, adjustedSize.z/2), SIMD3(-adjustedSize.x/2, -adjustedSize.y/2, adjustedSize.z/2)),
      (SIMD3(-adjustedSize.x/2, -adjustedSize.y/2, adjustedSize.z/2), SIMD3(-adjustedSize.x/2, -adjustedSize.y/2, -adjustedSize.z/2)),
      // 頂面 4 條邊
      (SIMD3(-adjustedSize.x/2, adjustedSize.y/2, -adjustedSize.z/2), SIMD3(adjustedSize.x/2, adjustedSize.y/2, -adjustedSize.z/2)),
      (SIMD3(adjustedSize.x/2, adjustedSize.y/2, -adjustedSize.z/2), SIMD3(adjustedSize.x/2, adjustedSize.y/2, adjustedSize.z/2)),
      (SIMD3(adjustedSize.x/2, adjustedSize.y/2, adjustedSize.z/2), SIMD3(-adjustedSize.x/2, adjustedSize.y/2, adjustedSize.z/2)),
      (SIMD3(-adjustedSize.x/2, adjustedSize.y/2, adjustedSize.z/2), SIMD3(-adjustedSize.x/2, adjustedSize.y/2, -adjustedSize.z/2)),
      // 4 條垂直邊
      (SIMD3(-adjustedSize.x/2, -adjustedSize.y/2, -adjustedSize.z/2), SIMD3(-adjustedSize.x/2, adjustedSize.y/2, -adjustedSize.z/2)),
      (SIMD3(adjustedSize.x/2, -adjustedSize.y/2, -adjustedSize.z/2), SIMD3(adjustedSize.x/2, adjustedSize.y/2, -adjustedSize.z/2)),
      (SIMD3(adjustedSize.x/2, -adjustedSize.y/2, adjustedSize.z/2), SIMD3(adjustedSize.x/2, adjustedSize.y/2, adjustedSize.z/2)),
      (SIMD3(-adjustedSize.x/2, -adjustedSize.y/2, adjustedSize.z/2), SIMD3(-adjustedSize.x/2, adjustedSize.y/2, adjustedSize.z/2))
    ]

    // 為每條邊創建線段
    for (index, edge) in edges.enumerated() {
      let lineLength = distance(edge.start, edge.end)
      let lineMesh = MeshResource.generateBox(size: SIMD3(lineLength, lineThickness, lineThickness))
      let lineEntity = ModelEntity(mesh: lineMesh, materials: [lineMaterial])
      lineEntity.name = "BoundingBoxEdge_\(index)"

      // 計算線段的中心點和方向
      let midPoint = (edge.start + edge.end) / 2
      let direction = normalize(edge.end - edge.start)

      // 設置線段位置
      lineEntity.position = midPoint

      // 計算旋轉：使線段沿著正確的方向
      if abs(direction.x) > 0.9 {
        // X 軸方向的邊，不需要旋轉
        lineEntity.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
      } else if abs(direction.y) > 0.9 {
        // Y 軸方向的邊
        lineEntity.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
      } else {
        // Z 軸方向的邊
        lineEntity.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])
      }

      boundingBoxContainer.addChild(lineEntity)
    }

    // 設置邊界框容器的位置（相對於實體的中心）
    boundingBoxContainer.position = bounds.center

    return boundingBoxContainer
  }

  private func addBoundingBoxesToAllEntities(_ entity: Entity) {
    // 只為最外層實體添加邊界框
    if let boundingBox = createWireframeBoundingBox(for: entity) {
      entity.addChild(boundingBox)

      // 計算並保存邊界框尺寸（使用世界座標空間以包含縮放變換）
      let bounds = entity.visualBounds(relativeTo: nil)
      // 儲存未縮放的原始尺寸（除以當前縮放比例）
      boundingBoxSizeOriginal = bounds.extents / scale

      print("📦 已為最外層實體 '\(entity.name.isEmpty ? "<unnamed>" : entity.name)' 添加邊界框")
      print("📏 邊界框原始尺寸: \(String(format: "(%.3f, %.3f, %.3f)", boundingBoxSizeOriginal.x, boundingBoxSizeOriginal.y, boundingBoxSizeOriginal.z))")
      print("📏 邊界框當前尺寸 (世界座標): \(String(format: "(%.3f, %.3f, %.3f)", boundingBoxSize.x, boundingBoxSize.y, boundingBoxSize.z))")
    }
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .top) {
        // 3D 模型檢視 - 佔據全螢幕接收手勢
        RealityView { rvc in
          // 儲存 content 參考以便投影計算
          realityViewContent = rvc
          viewSize = geometry.size

          do {
            let loadedBiplane = try Entity.load(named: "s60sj")
            biplane = loadedBiplane

          // 先生成碰撞形狀
          loadedBiplane.generateCollisionShapes(recursive: true)

          // 配置點擊檢測
          configureInputTarget(loadedBiplane)

          group.addChild(loadedBiplane)
          rvc.add(group)

          // 🎯 自動調整模型大小以符合螢幕
          let targetScale = calculateOptimalScale(for: loadedBiplane)
          group.scale = SIMD3<Float>(repeating: targetScale)
          scale = targetScale
          currentScale = targetScale

          // 計算模型的視覺邊界
          let bounds = loadedBiplane.visualBounds(relativeTo: nil)

          // 將模型的視覺中心對齊到 group 的原點（補償模型原點與視覺中心的偏移）
          loadedBiplane.position = SIMD3<Float>(
            -bounds.center.x,
            -bounds.center.y,
            -bounds.center.z
          )

          // 計算縮放後的模型高度，並將 group 放置在下方
          let modelHeight = bounds.extents.y * targetScale
          // 將模型底部對齊到視圖下方（-0.5 的位置）
          group.position = SIMD3<Float>(0, -0.5 + modelHeight / 2, 0)

//          // 保存原始狀態
//          originalGroupPosition = group.position
//          originalGroupScale = scale
//          originalGroupOrientation = group.orientation

//          rootEntity = loadedBiplane

          // 設定動畫
          setupAnimations()

          // 創建 3D 軸線（左下角參考用）
          createAxisLines()

          // 打印詳細模型資訊
          printDetailedModelInfo()

          // 為所有實體添加邊界框（為 group 添加，這樣可以看到整體邊界）
          print("\n🎯 ===== 開始添加邊界框 =====")
          addBoundingBoxesToAllEntities(group)
          print("🎯 ===== 邊界框添加完成 =====\n")
        } catch {
          print("載入模型失敗: \(error)")
        }
      }
      .gesture(
        // tap 和 backgroundTap 始終啟用
        backgroundTap
          .simultaneously(with: tap)
//          // 只有在非聚焦狀態時才啟用 drag 和 pinch
          .simultaneously(with: drag)
          .simultaneously(with: pinch)
//          .simultaneously(with: isFocused ? AnyGesture(TapGesture()) : AnyGesture(drag))
//          .simultaneously(with: isFocused ? AnyGesture(TapGesture()) : AnyGesture(pinch))
      ).border(.red)

      // 頂部狀態列
      VStack(spacing: 4) {
        // View 尺寸資訊
        HStack(spacing: 12) {
          Text("螢幕尺寸:")
            .font(.caption.bold())
            .foregroundColor(.primary)
          Text("W: \(String(format: "%.0f", viewSize.width))px")
            .font(.caption)
            .foregroundColor(.secondary)
          Text("H: \(String(format: "%.0f", viewSize.height))px")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.purple.opacity(0.2))
        .cornerRadius(8)
        .padding(.top, 8)
        .padding(.horizontal)

        HStack(spacing: 12) {
          // 縮放比例
          Text("縮放: \(String(format: "%.2f×", scale))")
            .font(.caption)
            .foregroundColor(.primary)

          Divider()
            .frame(height: 12)

          // X 軸旋轉
          VStack(alignment: .leading, spacing: 2) {
            Text("X: \(String(format: "%.0f°", rotationXDegrees))")
              .font(.caption)
            Text("\(String(format: "%.2f", rotationX)) rad")
              .font(.caption2)
              .foregroundColor(.secondary)
          }

          Divider()
            .frame(height: 12)

          // Y 軸旋轉
          VStack(alignment: .leading, spacing: 2) {
            Text("Y: \(String(format: "%.0f°", rotationYDegrees))")
              .font(.caption)
            Text("\(String(format: "%.2f", rotationY)) rad")
              .font(.caption2)
              .foregroundColor(.secondary)
          }

          Divider()
            .frame(height: 12)

          // 總旋轉角度
          VStack(alignment: .leading, spacing: 2) {
            Text("總: \(String(format: "%.0f°", totalRotationDegrees))")
              .font(.caption)
            Text("\(String(format: "%.2f", totalRotationAngle)) rad")
              .font(.caption2)
              .foregroundColor(.secondary)
          }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
        .padding(.top, 8)
        .padding(.horizontal)

        // 物件尺寸資訊
        if modelOriginalSize != SIMD3<Float>(0, 0, 0) {
          VStack(alignment: .leading, spacing: 6) {
            Text("物件尺寸")
              .font(.caption.bold())
              .foregroundColor(.primary)

            HStack(spacing: 12) {
              // 原始尺寸
              VStack(alignment: .leading, spacing: 2) {
                Text("原始")
                  .font(.caption2)
                  .foregroundColor(.secondary)
                HStack(spacing: 4) {
                  Text("W: \(String(format: "%.2f", modelOriginalSize.x))m")
                    .font(.caption2)
                  Text("H: \(String(format: "%.2f", modelOriginalSize.y))m")
                    .font(.caption2)
                  Text("D: \(String(format: "%.2f", modelOriginalSize.z))m")
                    .font(.caption2)
                }
              }

              Divider()
                .frame(height: 24)

              // 當前尺寸
              VStack(alignment: .leading, spacing: 2) {
                Text("當前 (\(String(format: "%.2f×", scale)))")
                  .font(.caption2)
                  .foregroundColor(.secondary)
                HStack(spacing: 4) {
                  Text("W: \(String(format: "%.3f", currentActualSize.x))m")
                    .font(.caption2)
                    .foregroundColor(currentActualSize.x > 1.0 ? .red : .primary)
                  Text("H: \(String(format: "%.3f", currentActualSize.y))m")
                    .font(.caption2)
                    .foregroundColor(currentActualSize.y > 1.0 ? .red : .primary)
                  Text("D: \(String(format: "%.3f", currentActualSize.z))m")
                    .font(.caption2)
                }
              }
            }

            // 邊界框尺寸
            if boundingBoxSize != SIMD3<Float>(0, 0, 0) {
              Divider()
                .frame(height: 1)
                .padding(.vertical, 4)

              VStack(alignment: .leading, spacing: 2) {
                Text("邊界框")
                  .font(.caption2)
                  .foregroundColor(.blue)
                HStack(spacing: 4) {
                  Text("W: \(String(format: "%.3f", boundingBoxSize.x))m")
                    .font(.caption2)
                    .foregroundColor(.blue)
                  Text("H: \(String(format: "%.3f", boundingBoxSize.y))m")
                    .font(.caption2)
                    .foregroundColor(.blue)
                  Text("D: \(String(format: "%.3f", boundingBoxSize.z))m")
                    .font(.caption2)
                    .foregroundColor(.blue)
                }
              }
            }

            // 警告提示
            if isOutOfScreen {
              Text("⚠️ 物件超出螢幕範圍（投影檢測）")
                .font(.caption2)
                .foregroundColor(.red)
            } else if currentActualSize.x > 1.0 || currentActualSize.y > 1.0 {
              Text("⚠️ 物件可能超出螢幕範圍")
                .font(.caption2)
                .foregroundColor(.red)
            } else if currentActualSize.x < 0.2 || currentActualSize.y < 0.2 {
              Text("⚠️ 物件可能太小")
                .font(.caption2)
                .foregroundColor(.orange)
            } else {
              Text("✅ 物件在螢幕範圍內")
                .font(.caption2)
                .foregroundColor(.green)
            }
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(Color.blue.opacity(0.15))
          .cornerRadius(8)
          .padding(.horizontal)
        }

        Spacer()
      }

      // UI 控制層 - 浮動在底部
      VStack {
        Spacer()

        // 動畫控制區域
        if !animationNames.isEmpty {
          VStack {
            HStack {
              Text("動畫選擇:")
              Picker("動畫", selection: $selectedAnimation) {
                ForEach(animationNames, id: \.self) { name in
                  Text(name).tag(name)
                }
              }
              .pickerStyle(MenuPickerStyle())
              .onChange(of: selectedAnimation) { _ in
                if isPlaying {
                  // 如果正在播放，自動切換到新動畫
                  playAnimation()
                }
              }
            }

            HStack(spacing: 20) {
              Button(isPlaying ? "停止" : "播放") {
                if isPlaying {
                  stopAnimation()
                } else {
                  playAnimation()
                }
              }
              .foregroundColor(isPlaying ? .red : .green)

              Button("分析結構") {
                printDetailedModelInfo()
              }
              .font(.caption)
              .buttonStyle(.bordered)
              
              Button("清除高亮") {
                for entity in highlightedEntities {
                  resetEntityColor(entity)
                }
              }
              .font(.caption)
              .buttonStyle(.bordered)
              
              Button("重置旋轉") {
                rotationX = 0.0
                rotationY = 0.0
                group.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
              }
              .font(.caption)
              .buttonStyle(.bordered)

              Text("狀態: \(isPlaying ? "播放中" : "已停止")")
                .font(.caption)
                .foregroundColor(.secondary)
            }

            // 快速動畫切換按鈕
            if animationNames.count > 1 {
              Text("快速切換:")
                .font(.caption)
                .foregroundColor(.secondary)

              ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                  ForEach(animationNames, id: \.self) { name in
                    Button(name) {
                      playAnimationByName(name)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    .background(selectedAnimation == name ? Color.blue.opacity(0.3) : Color.clear)
                    .cornerRadius(4)
                  }
                }
                .padding(.horizontal)
              }
            }
          }
          .padding()
          .background(Color.gray.opacity(0.1))
          .cornerRadius(8)
          .padding(.horizontal)
        }

        // 點擊資訊顯示
        if let entity = tappedEntity, let coordinates = tapCoordinates {
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("已選中物件")
                .font(.headline)
                .foregroundColor(.primary)

              Spacer()

              Button("清除") {
                tappedEntity = nil
                tapCoordinates = nil
              }
              .font(.caption)
              .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 4) {
              HStack {
                Text("名稱:")
                  .font(.caption)
                  .foregroundColor(.secondary)
                Text(entity.name.isEmpty ? "<未命名>" : entity.name)
                  .font(.caption.bold())
              }

              HStack {
                Text("ID:")
                  .font(.caption)
                  .foregroundColor(.secondary)
                Text("\(entity.id)")
                  .font(.caption.bold())
              }

              HStack {
                Text("座標:")
                  .font(.caption)
                  .foregroundColor(.secondary)
                Text(String(format: "(%.2f, %.2f, %.2f)", coordinates.x, coordinates.y, coordinates.z))
                  .font(.caption.bold())
              }

              HStack {
                Text("子物件:")
                  .font(.caption)
                  .foregroundColor(.secondary)
                Text("\(entity.children.count) 個")
                  .font(.caption.bold())
              }

              HStack {
                Text("路徑:")
                  .font(.caption)
                  .foregroundColor(.secondary)
                Spacer()
              }
              Text(getEntityPath(entity))
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
            }
          }
          .padding()
          .background(Color.blue.opacity(0.1))
          .cornerRadius(8)
          .padding(.horizontal)
        }

        // Bounding Box 尺寸資訊顯示（可折疊）
        VStack(alignment: .leading, spacing: 8) {
          // 標題列（可點擊折疊）
          Button(action: {
            withAnimation {
              showBoundingBoxInfo.toggle()
            }
          }) {
            HStack {
              Text("Bounding Box 尺寸")
                .font(.headline)
                .foregroundColor(.primary)
              Spacer()
              Image(systemName: showBoundingBoxInfo ? "chevron.up" : "chevron.down")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
          .buttonStyle(.plain)

          if showBoundingBoxInfo {
            VStack(alignment: .leading, spacing: 8) {
              // 3D 世界座標尺寸
              Text("3D 尺寸 (世界座標)")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
              
              HStack(spacing: 16) {
                // 寬度
                VStack(alignment: .leading, spacing: 2) {
                  Text("寬度")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                  Text("\(String(format: "%.3f", boundingBoxSize.x))m")
                    .font(.caption.bold())
                    .foregroundColor(.blue)
                }
                
                Divider()
                  .frame(height: 30)
                
                // 高度
                VStack(alignment: .leading, spacing: 2) {
                  Text("高度")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                  Text("\(String(format: "%.3f", boundingBoxSize.y))m")
                    .font(.caption.bold())
                    .foregroundColor(.blue)
                }
                
                Divider()
                  .frame(height: 30)
                
                // 深度
                VStack(alignment: .leading, spacing: 2) {
                  Text("深度")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                  Text("\(String(format: "%.3f", boundingBoxSize.z))m")
                    .font(.caption.bold())
                    .foregroundColor(.blue)
                }
              }
              
              // 分隔線
              Divider()
              
              // 2D 螢幕投影尺寸
              Text("2D 投影尺寸 (螢幕座標)")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
              
              HStack(spacing: 16) {
                // 投影寬度
                VStack(alignment: .leading, spacing: 2) {
                  Text("投影寬度")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                  Text("\(String(format: "%.0f", projectedScreenSize.width))px")
                    .font(.caption.bold())
                    .foregroundColor(.purple)
                }
                
                Divider()
                  .frame(height: 30)
                
                // 投影高度
                VStack(alignment: .leading, spacing: 2) {
                  Text("投影高度")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                  Text("\(String(format: "%.0f", projectedScreenSize.height))px")
                    .font(.caption.bold())
                    .foregroundColor(.purple)
                }
                
                Divider()
                  .frame(height: 30)
                
                // 佔螢幕比例
                VStack(alignment: .leading, spacing: 2) {
                  Text("佔螢幕比例")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                  if viewSize.width > 0 && viewSize.height > 0 {
                    Text("\(String(format: "%.1f", projectedScreenSize.width / viewSize.width * 100))% × \(String(format: "%.1f", projectedScreenSize.height / viewSize.height * 100))%")
                      .font(.caption.bold())
                      .foregroundColor(.orange)
                  } else {
                    Text("--")
                      .font(.caption.bold())
                      .foregroundColor(.secondary)
                  }
                }
              }
            }
            
            // 投影檢測狀態
            HStack(spacing: 8) {
              Text("投影檢測:")
                .font(.caption)
                .foregroundColor(.secondary)
              if isOutOfScreen {
                Text("超出螢幕範圍")
                  .font(.caption)
                  .foregroundColor(.red)
              } else {
                Text("在螢幕範圍內")
                  .font(.caption)
                  .foregroundColor(.green)
              }
            }
          }
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
      }
      }
    }
  }
}

#Preview("TestRealityKit") {
  TestRealityKit()
}
