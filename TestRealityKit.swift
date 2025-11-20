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
  let group = AnchorEntity()
  @State private var biplane: Entity?
  
  // 動畫控制
  @State private var availableAnimations: [AnimationResource] = []
  @State private var animationNames: [String] = []
  @State private var selectedAnimation: String = ""
  @State private var isPlaying: Bool = false
  
  // base_telescope 控制
  @State private var baseTelescope: Entity?
  @State private var baseTelescopeRotation: Float = 0.0  // Yaw (左右旋轉)
  @State private var baseTelescopeRotationX: Float = 0.0  // Pitch (上下抬頭)
  
  // fly_telescope 控制
  @State private var flyTelescope: Entity?
  @State private var originalFlyTelescopeParent: Entity?
  @State private var isFlyBoundToBase: Bool = false
  
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
  @State private var showCameraControls: Bool = false
  @State private var showTelescopeControls: Bool = false
  @State private var showAnimationControls: Bool = false
  @State private var showEntityInfo: Bool = false
  
  // 相機控制
  @State private var cameraEntity: Entity?
  @State private var cameraType: CameraType = .perspective
  @State private var cameraFOV: Float = 60.0  // 視野角度 (30-120度)
  @State private var cameraDistance: Float = 1.0  // 相機距離 (0.5-3.0m)
  @State private var focusedEntity: Entity?
  @State private var defaultCameraPosition: SIMD3<Float> = SIMD3<Float>(0, 0, 1.0)
  @State private var focusOutlineEntity: Entity?  // 聚焦輪廓
  @State private var cameraAzimuth: Float = 0.0  // 水平旋轉角度
  @State private var cameraElevation: Float = 0.0  // 垂直旋轉角度
  @State private var orbitCenter: SIMD3<Float> = SIMD3<Float>(0, 0, 0)  // 相機環繞中心點
  @State private var baseCameraDistance: Float = 1.0  // Pinch 手勢開始時的相機距離

  // 相機類型
  enum CameraType {
    case perspective  // 透視相機
  }
  
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
  
  // 計算當前邊界框尺寸（模型保持原始大小，不進行縮放）
  private var boundingBoxSize: SIMD3<Float> {
    boundingBoxSizeOriginal
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
        // 水平拖曳 → 更新方位角（環繞 Y 軸）
        cameraAzimuth += Float(value.translation.width) * ratio

        // 垂直拖曳 → 更新仰角（上下環繞）
        let newElevation = cameraElevation - Float(value.translation.height) * ratio

        // 限制仰角在 0° 到 +85° 之間（只能往上看，避免翻轉）
        let maxElevation: Float = .pi * 85 / 180  // 85° ≈ 1.484 弧度
        cameraElevation = max(0, min(maxElevation, newElevation))

        // 更新相機位置（環繞模型）
        updateCameraOrbit()
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
      .onEnded { _ in
        handleEntityRelease()
      }
  }
  
  var pinch: some Gesture {
    MagnificationGesture()
      .onChanged { mag in
        print("Pinch detected: \(mag)")
        let newDistance = baseCameraDistance / Float(mag)
        cameraDistance = min(max(newDistance, 0.5), 3.0)
        print("Camera distance: \(cameraDistance)m")
        updateCameraOrbit()
      }
      .onEnded { _ in
        print("Pinch ended, camera distance: \(cameraDistance)m")
        baseCameraDistance = cameraDistance
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
  
  // 根據名稱查找實體（遞迴搜尋）
  private func findEntityByName(_ name: String, in entity: Entity) -> Entity? {
    // 檢查當前實體
    if entity.name == name {
      return entity
    }
    
    // 遞迴搜尋子實體
    for child in entity.children {
      if let found = findEntityByName(name, in: child) {
        return found
      }
    }
    
    return nil
  }
  
  // 旋轉軸枚舉
  enum RotationAxis {
    case x  // Pitch (上下抬頭)
    case y  // Yaw (左右旋轉)
  }
  
  // 旋轉 base_telescope
  private func rotateBaseTelescope(by angle: Float, axis: RotationAxis) {
    guard let telescope = baseTelescope else {
      print("❌ base_telescope 未找到")
      return
    }
    
    switch axis {
    case .x:
      let newRotationX = baseTelescopeRotationX + angle
      // 限制 pitch 在 -60° 到 +60° 之間，避免翻轉
      baseTelescopeRotationX = max(-Float.pi / 3, min(Float.pi / 3, newRotationX))
      print("🔄 base_telescope pitch (上下): \(String(format: "%.0f°", baseTelescopeRotationX * 180 / .pi))")
      
    case .y:
      baseTelescopeRotation += angle
      print("🔄 base_telescope yaw (左右): \(String(format: "%.0f°", baseTelescopeRotation * 180 / .pi))")
    }
    
    // 組合 X 和 Y 軸旋轉
    let rotationQuatX = simd_quatf(angle: baseTelescopeRotationX, axis: [1, 0, 0])
    let rotationQuatY = simd_quatf(angle: baseTelescopeRotation, axis: [0, 1, 0])
    
    // 先應用 Y 軸旋轉（yaw），再應用 X 軸旋轉（pitch）
    telescope.orientation = rotationQuatY * rotationQuatX
  }
  
  // 重置 base_telescope 旋轉
  private func resetBaseTelescopeRotation() {
    guard let telescope = baseTelescope else {
      print("❌ base_telescope 未找到")
      return
    }
    
    baseTelescopeRotation = 0.0
    baseTelescopeRotationX = 0.0
    telescope.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
    print("🔄 base_telescope 已重置旋轉（X 和 Y 軸）")
  }
  
  // 綁定 fly_telescope 到 base_telescope
  private func bindFlyTelescopeToBase() {
    guard let fly = flyTelescope,
          let base = baseTelescope else {
      print("❌ 無法綁定：找不到 fly_telescope 或 base_telescope")
      return
    }
    
    guard !isFlyBoundToBase else {
      print("⚠️ fly_telescope 已經綁定到 base_telescope")
      return
    }
    
    print("\n🔗 ===== 開始綁定 fly_telescope =====")
    
    // 保存原始父實體
    originalFlyTelescopeParent = fly.parent
    print("📍 原始父實體: \(originalFlyTelescopeParent?.name ?? "<none>")")
    
    // 保存世界座標、方向和縮放（綁定前）
    let worldPosition = fly.position(relativeTo: nil)
    let worldOrientation = fly.orientation(relativeTo: nil)
    let worldScale = fly.scale(relativeTo: nil)
    print("🌍 世界座標（綁定前）: \(worldPosition)")
    print("🧭 世界方向（綁定前）: \(worldOrientation)")
    print("📏 世界縮放（綁定前）: \(worldScale)")
    
    // 從原父實體移除
    fly.removeFromParent()
    print("✂️ 已從原父實體移除")
    
    // 添加為 base_telescope 的子實體
    base.addChild(fly)
    print("✅ 已添加為 base_telescope 的子實體")
    
    // 使用 setPosition、setOrientation 和 setScale 恢復世界座標
    fly.setPosition(worldPosition, relativeTo: nil)
    fly.setOrientation(worldOrientation, relativeTo: nil)
    fly.setScale(worldScale, relativeTo: nil)
    print("📍 已恢復世界座標、方向和縮放")
    
    // 驗證世界座標是否保持不變
    let newWorldPosition = fly.position(relativeTo: nil)
    let newWorldOrientation = fly.orientation(relativeTo: nil)
    let newWorldScale = fly.scale(relativeTo: nil)
    print("🌍 世界座標（綁定後）: \(newWorldPosition)")
    print("🧭 世界方向（綁定後）: \(newWorldOrientation)")
    print("📏 世界縮放（綁定後）: \(newWorldScale)")
    print("📏 位置差異: \(distance(worldPosition, newWorldPosition))m")
    print("📏 縮放差異: \(distance(worldScale, newWorldScale))")
    
    // 輸出局部座標（相對於 base）
    print("📍 局部座標（相對於 base）: \(fly.position)")
    print("🧭 局部方向（相對於 base）: \(fly.orientation)")
    print("📏 局部縮放（相對於 base）: \(fly.scale)")
    
    // 更新綁定狀態
    isFlyBoundToBase = true
    print("🔗 ===== 綁定完成 =====\n")
  }
  
  // 解除 fly_telescope 與 base_telescope 的綁定
  private func unbindFlyTelescopeFromBase() {
    guard let fly = flyTelescope,
          let originalParent = originalFlyTelescopeParent else {
      print("❌ 無法解除綁定：找不到 fly_telescope 或原始父實體")
      return
    }
    
    guard isFlyBoundToBase else {
      print("⚠️ fly_telescope 未綁定到 base_telescope")
      return
    }
    
    print("\n🔓 ===== 開始解除綁定 fly_telescope =====")
    
    // 保存世界座標、方向和縮放（解綁前）
    let worldPosition = fly.position(relativeTo: nil)
    let worldOrientation = fly.orientation(relativeTo: nil)
    let worldScale = fly.scale(relativeTo: nil)
    print("🌍 世界座標（解綁前）: \(worldPosition)")
    print("🧭 世界方向（解綁前）: \(worldOrientation)")
    print("📏 世界縮放（解綁前）: \(worldScale)")
    
    // 從 base_telescope 移除
    fly.removeFromParent()
    print("✂️ 已從 base_telescope 移除")
    
    // 添加回原父實體
    originalParent.addChild(fly)
    print("✅ 已添加回原父實體: \(originalParent.name)")
    
    // 使用 setPosition、setOrientation 和 setScale 恢復世界座標
    fly.setPosition(worldPosition, relativeTo: nil)
    fly.setOrientation(worldOrientation, relativeTo: nil)
    fly.setScale(worldScale, relativeTo: nil)
    print("📍 已恢復世界座標、方向和縮放")
    
    // 驗證世界座標是否保持不變
    let newWorldPosition = fly.position(relativeTo: nil)
    let newWorldOrientation = fly.orientation(relativeTo: nil)
    let newWorldScale = fly.scale(relativeTo: nil)
    print("🌍 世界座標（解綁後）: \(newWorldPosition)")
    print("🧭 世界方向（解綁後）: \(newWorldOrientation)")
    print("📏 世界縮放（解綁後）: \(newWorldScale)")
    print("📏 位置差異: \(distance(worldPosition, newWorldPosition))m")
    print("📏 縮放差異: \(distance(worldScale, newWorldScale))")
    
    // 輸出局部座標（相對於原父實體）
    print("📍 局部座標（相對於原父實體）: \(fly.position)")
    print("🧭 局部方向（相對於原父實體）: \(fly.orientation)")
    print("📏 局部縮放（相對於原父實體）: \(fly.scale)")
    
    // 更新綁定狀態
    isFlyBoundToBase = false
    print("🔓 ===== 解除綁定完成 =====\n")
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
    
    // ⭐ 自動聚焦到點擊的實體（focusedEntity 會在 focusOnEntity 內部設置）
    focusOnEntity(entity, duration: 0.5)
    
    // 顯示所有子實體
    print("👶 子實體數量: \(entity.children.count)")
    for (index, child) in entity.children.enumerated() {
      print("  [\(index)] \(child.name.isEmpty ? "<unnamed>" : child.name)")
    }
  }
  
  private func handleEntityRelease() {
    if let entity = pressedEntity {
      print("👆 釋放實體: \(entity.name.isEmpty ? "<unnamed>" : entity.name)")
      // 只在實體不是聚焦實體時重置顏色（聚焦實體保持藍色高亮）
      if entity != focusedEntity {
        resetEntityColor(entity)
      } else {
        print("💎 保持聚焦實體的藍色高亮")
      }
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
  
  private func createAxisLines() -> Entity {
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

    // 創建一個容器來放置軸線，放在左上角
    let axisContainer = Entity()
    axisContainer.name = "AxisLines"
    axisContainer.addChild(xAxis)
    axisContainer.addChild(yAxis)
    axisContainer.addChild(zAxis)

    // 放在左上角，不干擾主模型（不受 group.scale 影響）
    axisContainer.position = SIMD3<Float>(0, 0, 0)

    print("✅ 已創建 3D 軸線（左上角）：")
    print("   🔴 X 軸（紅色）- 向右")
    print("   🟢 Y 軸（綠色）- 向上")
    print("   🔵 Z 軸（藍色）- 向前")
    print("   ⭐ 固定尺寸，不受模型縮放影響")

    return axisContainer
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
  
  private func setupModelBounds(for entity: Entity) -> Float {
    // 獲取模型的視覺邊界（這個尺寸已經考慮了 metersPerUnit）
    let bounds = entity.visualBounds(relativeTo: nil)
    let modelSize = bounds.extents

    print("📏 模型載入後的物理尺寸: \(String(format: "(%.3f, %.3f, %.3f)", modelSize.x, modelSize.y, modelSize.z))m")

    // 找出模型最大的維度
    let maxDimension = max(modelSize.x, max(modelSize.y, modelSize.z))
    print("📏 模型最大維度: \(String(format: "%.3f", maxDimension))m")

    // 計算標準化縮放比例（將最大維度縮放到 1m）
    let normalizedScale = 1.0 / maxDimension
    print("📐 標準化縮放比例: \(String(format: "%.6f", normalizedScale))")

    // 保存標準化後的模型尺寸
    modelOriginalSize = modelSize * normalizedScale
    print("📦 標準化後尺寸: \(String(format: "(%.3f, %.3f, %.3f)", modelOriginalSize.x, modelOriginalSize.y, modelOriginalSize.z))m")

    return normalizedScale
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
      
      // 計算並保存邊界框尺寸（使用世界座標空間）
      let bounds = entity.visualBounds(relativeTo: nil)
      // 儲存原始尺寸（模型保持原始大小，不進行縮放）
      boundingBoxSizeOriginal = bounds.extents
      
      print("📦 已為最外層實體 '\(entity.name.isEmpty ? "<unnamed>" : entity.name)' 添加邊界框")
      print("📏 邊界框原始尺寸: \(String(format: "(%.3f, %.3f, %.3f)", boundingBoxSizeOriginal.x, boundingBoxSizeOriginal.y, boundingBoxSizeOriginal.z))")
      print("📏 邊界框當前尺寸 (世界座標): \(String(format: "(%.3f, %.3f, %.3f)", boundingBoxSize.x, boundingBoxSize.y, boundingBoxSize.z))")
    }
  }
  
  /// 為聚焦實體創建金色發光輪廓
  /// - Parameter entity: 要添加輪廓的實體
  /// - Returns: 輪廓 entity（如果成功創建）
  private func createFocusOutline(for entity: Entity) -> Entity? {
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
    
    // 稍微放大輪廓，使其包圍實體（增加 5% 的間距）
    let outlineSize = adjustedSize * 1.05
    
    // 創建輪廓容器
    let outlineContainer = Entity()
    outlineContainer.name = "FocusOutline_\(entity.name.isEmpty ? "unnamed" : entity.name)"
    
    // 線條粗細（比普通邊界框粗一些）
    let lineThickness: Float = 0.006
    
    // 創建金色發光材質
    var lineMaterial = SimpleMaterial()
    lineMaterial.color = .init(tint: .systemYellow, texture: nil)
    lineMaterial.metallic = 0.8  // 增加金屬感
    lineMaterial.roughness = 0.2  // 降低粗糙度，更光滑
    
    // 創建 12 條邊線（立方體有 12 條邊）
    let edges: [(start: SIMD3<Float>, end: SIMD3<Float>)] = [
      // 底面 4 條邊
      (SIMD3(-outlineSize.x/2, -outlineSize.y/2, -outlineSize.z/2), SIMD3(outlineSize.x/2, -outlineSize.y/2, -outlineSize.z/2)),
      (SIMD3(outlineSize.x/2, -outlineSize.y/2, -outlineSize.z/2), SIMD3(outlineSize.x/2, -outlineSize.y/2, outlineSize.z/2)),
      (SIMD3(outlineSize.x/2, -outlineSize.y/2, outlineSize.z/2), SIMD3(-outlineSize.x/2, -outlineSize.y/2, outlineSize.z/2)),
      (SIMD3(-outlineSize.x/2, -outlineSize.y/2, outlineSize.z/2), SIMD3(-outlineSize.x/2, -outlineSize.y/2, -outlineSize.z/2)),
      // 頂面 4 條邊
      (SIMD3(-outlineSize.x/2, outlineSize.y/2, -outlineSize.z/2), SIMD3(outlineSize.x/2, outlineSize.y/2, -outlineSize.z/2)),
      (SIMD3(outlineSize.x/2, outlineSize.y/2, -outlineSize.z/2), SIMD3(outlineSize.x/2, outlineSize.y/2, outlineSize.z/2)),
      (SIMD3(outlineSize.x/2, outlineSize.y/2, outlineSize.z/2), SIMD3(-outlineSize.x/2, outlineSize.y/2, outlineSize.z/2)),
      (SIMD3(-outlineSize.x/2, outlineSize.y/2, outlineSize.z/2), SIMD3(-outlineSize.x/2, outlineSize.y/2, -outlineSize.z/2)),
      // 4 條垂直邊
      (SIMD3(-outlineSize.x/2, -outlineSize.y/2, -outlineSize.z/2), SIMD3(-outlineSize.x/2, outlineSize.y/2, -outlineSize.z/2)),
      (SIMD3(outlineSize.x/2, -outlineSize.y/2, -outlineSize.z/2), SIMD3(outlineSize.x/2, outlineSize.y/2, -outlineSize.z/2)),
      (SIMD3(outlineSize.x/2, -outlineSize.y/2, outlineSize.z/2), SIMD3(outlineSize.x/2, outlineSize.y/2, outlineSize.z/2)),
      (SIMD3(-outlineSize.x/2, -outlineSize.y/2, outlineSize.z/2), SIMD3(-outlineSize.x/2, outlineSize.y/2, outlineSize.z/2))
    ]
    
    // 為每條邊創建線段
    for (index, edge) in edges.enumerated() {
      let lineLength = distance(edge.start, edge.end)
      let lineMesh = MeshResource.generateBox(size: SIMD3(lineLength, lineThickness, lineThickness))
      let lineEntity = ModelEntity(mesh: lineMesh, materials: [lineMaterial])
      lineEntity.name = "FocusOutlineEdge_\(index)"
      
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
      
      outlineContainer.addChild(lineEntity)
    }
    
    // 設置輪廓容器的位置（相對於實體的中心）
    outlineContainer.position = bounds.center
    
    return outlineContainer
  }
  
  /// 移除當前的聚焦輪廓
  private func removeFocusOutline() {
    if let outline = focusOutlineEntity {
      outline.removeFromParent()
      focusOutlineEntity = nil
      print("🗑️ 已移除聚焦輪廓")
    }
  }
  
  // MARK: - Camera Control Functions

  /// 更新相機環繞位置（基於球面座標）
  private func updateCameraOrbit() {
    guard let camera = cameraEntity else {
      return
    }

    // 將球面座標轉換為笛卡爾座標
    let x = orbitCenter.x + cameraDistance * cos(cameraElevation) * sin(cameraAzimuth)
    let y = orbitCenter.y + cameraDistance * sin(cameraElevation)
    let z = orbitCenter.z + cameraDistance * cos(cameraElevation) * cos(cameraAzimuth)

    let newPosition = SIMD3<Float>(x, y, z)

    // 立即更新相機位置（無動畫）
    camera.position = newPosition

    // 讓相機看向環繞中心點
    camera.look(at: orbitCenter, from: newPosition, relativeTo: nil)
  }

  /// 切換相機類型
  /// - Parameter type: 目標相機類型
  private func switchCamera(to type: CameraType) {
    guard let entity = cameraEntity else {
      print("❌ 相機未初始化")
      return
    }
    
    print("🔄 切換相機類型: \(cameraType) → \(type)")
    
    cameraType = type
    
    // 移除舊的相機組件
    entity.components.remove(PerspectiveCameraComponent.self)
    
    // 根據類型設置新的相機組件
    switch type {
    case .perspective:
      var component = PerspectiveCameraComponent()
      component.fieldOfViewInDegrees = cameraFOV
      component.near = 0.01
      component.far = 100.0
      entity.components.set(component)
      print("📸 已切換到透視相機 (FOV: \(cameraFOV)°)")
    }
    
    print("✅ 相機切換完成")
  }
  
  /// 計算相機距離以完整框住物體
  /// - Parameters:
  ///   - objectSize: 物體尺寸（使用最大維度）
  ///   - fovDegrees: 相機視野角度（度數）
  /// - Returns: 相機到物體中心的距離
  private func calculateOptimalDistance(objectSize: Float, fovDegrees: Float) -> Float {
    // 轉換 FOV 為弧度
    let fovRadians = fovDegrees * .pi / 180.0
    
    // 計算半角
    let halfAngle = fovRadians / 2.0
    
    // 距離公式: d = (objectSize / 2) / tan(halfAngle)
    // 添加 1.3 的填充係數以獲得舒適的框架
    let distance = (objectSize / 2.0) / tan(halfAngle) * 1.3
    
    return distance
  }
  
  /// 聚焦到指定實體
  /// - Parameters:
  ///   - entity: 要聚焦的實體
  ///   - duration: 動畫持續時間
  private func focusOnEntity(_ entity: Entity, duration: TimeInterval = 0.5) {
    guard let cameraEntity = getActiveCameraEntity() else {
      print("❌ 相機未初始化")
      return
    }

    print("🎯 聚焦到實體: \(entity.name.isEmpty ? "<unnamed>" : entity.name)")

    // 🗑️ 移除之前的聚焦輪廓並重置顏色（如果存在）
    if let previousEntity = focusedEntity, previousEntity != entity {
      resetEntityColor(previousEntity)
      print("🔄 重置之前聚焦實體的顏色")
    }
    removeFocusOutline()

    // 獲取實體邊界
    let bounds = entity.visualBounds(relativeTo: nil)
    let entityCenter = bounds.center
    let maxDimension = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))

    print("📏 實體中心: \(entityCenter)")
    print("📏 最大維度: \(maxDimension)m")

    // 計算最佳距離
    let optimalDistance = calculateOptimalDistance(objectSize: maxDimension, fovDegrees: cameraFOV)

    // 🔄 更新環繞中心為實體中心
    orbitCenter = entityCenter

    // 📸 保持當前的相機方位角和仰角，只調整距離
    cameraDistance = optimalDistance

    // 🎬 使用環繞系統計算新的相機位置（基於當前的 azimuth 和 elevation）
    let x = orbitCenter.x + cameraDistance * cos(cameraElevation) * sin(cameraAzimuth)
    let y = orbitCenter.y + cameraDistance * sin(cameraElevation)
    let z = orbitCenter.z + cameraDistance * cos(cameraElevation) * cos(cameraAzimuth)

    let newPosition = SIMD3<Float>(x, y, z)

    print("📸 當前方位角: \(String(format: "%.0f°", cameraAzimuth * 180 / .pi))")
    print("📸 當前仰角: \(String(format: "%.0f°", cameraElevation * 180 / .pi))")
    print("📸 新相機位置: \(newPosition)")
    print("📸 最佳距離: \(optimalDistance)m")

    // 動畫相機移動到新位置
    let targetTransform = Transform(
      scale: cameraEntity.scale,
      rotation: cameraEntity.orientation,
      translation: newPosition
    )

    cameraEntity.move(
      to: targetTransform,
      relativeTo: nil,
      duration: duration,
      timingFunction: .easeInOut
    )

    // 讓相機看向實體中心
    cameraEntity.look(at: entityCenter, from: newPosition, relativeTo: nil)

    // 🌟 為聚焦實體添加金色輪廓
    if let outline = createFocusOutline(for: entity) {
      entity.addChild(outline)
      focusOutlineEntity = outline
      print("✨ 已添加金色聚焦輪廓")
    }

    // 🎯 設置為聚焦實體（在重置舊實體顏色之後）
    focusedEntity = entity
    print("🎯 已設置聚焦實體")

    print("✅ 聚焦完成")
  }
  
  /// 平滑改變相機 FOV
  /// - Parameters:
  ///   - targetFOV: 目標 FOV（度數）
  ///   - duration: 動畫持續時間
  private func animateCameraFOV(to targetFOV: Float, duration: TimeInterval = 0.3) {
    guard let entity = cameraEntity else { return }
    
    let startFOV = cameraFOV
    let startTime = Date()
    
    print("🎥 FOV 動畫: \(startFOV)° → \(targetFOV)°")
    
    Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { timer in
      let elapsed = Date().timeIntervalSince(startTime)
      let progress = min(elapsed / duration, 1.0)
      
      // Ease-in-out 插值
      let t = progress < 0.5
      ? 2 * progress * progress
      : -1 + (4 - 2 * progress) * progress
      
      let currentFOV = startFOV + (targetFOV - startFOV) * Float(t)
      
      // 更新 PerspectiveCameraComponent
      if var cameraComponent = entity.components[PerspectiveCameraComponent.self] {
        cameraComponent.fieldOfViewInDegrees = currentFOV
        entity.components.set(cameraComponent)
      }
      
      if progress >= 1.0 {
        timer.invalidate()
        print("✅ FOV 動畫完成: \(targetFOV)°")
      }
    }
  }
  
  /// 平滑改變相機距離
  /// - Parameters:
  ///   - targetDistance: 目標距離
  ///   - duration: 動畫持續時間
  private func animateCameraDistance(to targetDistance: Float, duration: TimeInterval = 0.3) {
    guard let cameraEntity = getActiveCameraEntity() else { return }
    
    // 保持當前方向，只改變距離
    let currentPosition = cameraEntity.position
    let direction = normalize(currentPosition)
    let newPosition = direction * targetDistance
    
    print("📏 距離動畫: \(length(currentPosition))m → \(targetDistance)m")
    
    let targetTransform = Transform(
      scale: cameraEntity.scale,
      rotation: cameraEntity.orientation,  // 保持當前方向不變
      translation: newPosition
    )
    
    cameraEntity.move(
      to: targetTransform,
      relativeTo: nil,
      duration: duration,
      timingFunction: .easeInOut
    )
    
    // 移除 look 調用 - 它會干擾 move 動畫
    // 相機方向已經在 Transform 中設置，不需要額外調整
  }
  
  /// 重置相機視角
  private func resetCameraView() {
    guard let cameraEntity = getActiveCameraEntity() else { return }

    print("🔄 重置相機視角")

    // 重置 FOV（透視相機）
    cameraFOV = 60.0
    animateCameraFOV(to: 60.0, duration: 0.5)

    if let _ = focusedEntity {
      // 🎯 有 focus 實體：只調整距離，保持方位角和仰角
      print("🎯 偵測到 focus 實體，保持當前視角")

      // 計算能看到整個場景的距離
      let bounds = group.visualBounds(relativeTo: nil)
      let maxDimension = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
      let optimalDistance = calculateOptimalDistance(objectSize: maxDimension, fovDegrees: cameraFOV)

      // 更新環繞中心為整個場景的中心
      orbitCenter = bounds.center

      // 更新距離（保持方位角和仰角）
      cameraDistance = optimalDistance
      baseCameraDistance = optimalDistance

      // 使用環繞系統更新相機位置（保持 azimuth 和 elevation）
      updateCameraOrbit()

      print("📸 已重置距離到: \(optimalDistance)m")
      print("🔄 保持方位角: \(String(format: "%.0f°", cameraAzimuth * 180 / .pi))")
      print("🔄 保持仰角: \(String(format: "%.0f°", cameraElevation * 180 / .pi))")
      print("🎯 保持 focus 狀態")

    } else {
      // 🔄 沒有 focus 實體：完整重置
      print("🔄 執行完整重置")

      cameraDistance = 1.0

      let targetTransform = Transform(
        scale: cameraEntity.scale,
        rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
        translation: defaultCameraPosition
      )

      cameraEntity.move(
        to: targetTransform,
        relativeTo: nil,
        duration: 0.5,
        timingFunction: .easeInOut
      )

      cameraEntity.look(at: [0, 0, 0], from: defaultCameraPosition, relativeTo: nil)

      // 重置環繞狀態
      cameraAzimuth = 0.0
      cameraElevation = 0.0
      orbitCenter = SIMD3<Float>(0, 0, 0)
      baseCameraDistance = 1.0
    }

    print("✅ 相機重置完成")
  }
  
  /// 獲取當前活動相機實體
  private func getActiveCameraEntity() -> Entity? {
    return cameraEntity
  }

  /// 釋放當前聚焦的實體
  private func releaseFocus() {
    guard let entity = focusedEntity else {
      print("⚠️ 沒有聚焦的實體")
      return
    }

    print("🔓 釋放聚焦: \(entity.name.isEmpty ? "<unnamed>" : entity.name)")

    // 重置實體顏色
    resetEntityColor(entity)

    // 移除聚焦輪廓
    removeFocusOutline()

    // 清除聚焦實體
    focusedEntity = nil

    print("✅ 聚焦已釋放")
  }
  
  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .top) {
        // 3D 模型檢視 - 佔據全螢幕接收手勢
        RealityView { rvc in
          // 儲存 content 參考以便投影計算
          realityViewContent = rvc
          viewSize = geometry.size
          
          // 🎥 設置自定義相機模式
          rvc.camera = .virtual
          print("🎥 已啟用虛擬相機模式")
          
          do {
            let loadedBiplane = try Entity.load(named: "boomlift_without_animation")
            biplane = loadedBiplane
            
            // 先生成碰撞形狀
            loadedBiplane.generateCollisionShapes(recursive: true)
            
            // 配置點擊檢測
            configureInputTarget(loadedBiplane)
            
            group.addChild(loadedBiplane)
            rvc.add(group)

            // 🎯 計算並應用初始縮放（將模型標準化到最大維度 1m）
            let normalizedScale = setupModelBounds(for: loadedBiplane)
            group.scale = SIMD3<Float>(repeating: normalizedScale)
            print("📦 已應用標準化縮放: \(normalizedScale)")

            // 計算模型的視覺邊界（縮放前的原始邊界）
            let biplaneBounds = loadedBiplane.visualBounds(relativeTo: nil)

            // 將模型的視覺中心對齊到 group 的原點（補償模型原點與視覺中心的偏移）
            loadedBiplane.position = SIMD3<Float>(
              -biplaneBounds.center.x,
               -biplaneBounds.center.y,
               -biplaneBounds.center.z
            )

            // 使用標準化後的模型高度來設置 group 位置
            let normalizedHeight = biplaneBounds.extents.y * normalizedScale
            // 將模型底部對齊到視圖下方
            group.position = SIMD3<Float>(0,  -normalizedHeight / 2, 0)
            print("📍 Group 位置: \(group.position)")
            print("📏 標準化後高度: \(normalizedHeight)m")
            
            //          // 保存原始狀態
            //          originalGroupPosition = group.position
            //          originalGroupScale = scale
            //          originalGroupOrientation = group.orientation
            
            //          rootEntity = loadedBiplane
            
            // 設定動畫
            setupAnimations()

            // 創建 3D 軸線（左上角參考用，固定尺寸不受模型縮放影響）
            let axisLines = createAxisLines()
            rvc.add(axisLines)

            // 打印詳細模型資訊
            printDetailedModelInfo()
            
            // 查找 base_telescope
            print("\n🔍 ===== 開始搜尋 base_telescope =====")
            if let telescope = findEntityByName("base_telescope", in: loadedBiplane) {
              baseTelescope = telescope
              print("✅ 找到 base_telescope！")
              print("   名稱: \(telescope.name)")
              print("   ID: \(telescope.id)")
              print("   座標: \(telescope.position)")
              print("   子物件數量: \(telescope.children.count)")
            } else {
              print("❌ 未找到 base_telescope")
            }
            print("🔍 ===== 搜尋完成 =====\n")
            
            // 查找 fly_telescope
            print("🔍 ===== 開始搜尋 fly_telescope =====")
            if let fly = findEntityByName("fly_telescope", in: loadedBiplane) {
              flyTelescope = fly
              print("✅ 找到 fly_telescope！")
              print("   名稱: \(fly.name)")
              print("   ID: \(fly.id)")
              print("   世界座標: \(fly.position(relativeTo: nil))")
              print("   局部座標: \(fly.position)")
              print("   父實體: \(fly.parent?.name ?? "<none>")")
              print("   子物件數量: \(fly.children.count)")
            } else {
              print("❌ 未找到 fly_telescope")
            }
            print("🔍 ===== 搜尋完成 =====\n")
            
            // 為所有實體添加邊界框（為 group 添加，這樣可以看到整體邊界）
            print("\n🎯 ===== 開始添加邊界框 =====")
            addBoundingBoxesToAllEntities(group)
            print("🎯 ===== 邊界框添加完成 =====\n")
            
            // 🎥 設置自定義相機（使用 Component 方式 - 動態切換）
            print("\n🎥 ===== 開始設置相機 (Component) =====")
            
            // 計算最佳相機位置（基於模型尺寸）
            let bounds = group.visualBounds(relativeTo: nil)
            let maxDimension = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
            let optimalDistance = calculateOptimalDistance(objectSize: maxDimension, fovDegrees: cameraFOV)
            let cameraPosition = SIMD3<Float>(0, 0, optimalDistance)
            
            // 創建相機實體
            let camera = Entity()
            
            // 設置透視相機組件
            var component = PerspectiveCameraComponent()
            component.fieldOfViewInDegrees = cameraFOV
            component.near = 0.01
            component.far = 100.0
            camera.components.set(component)
            print("📸 初始相機類型: 透視相機 (FOV: \(cameraFOV)°)")
            
            // 設置位置和方向
            camera.look(at: [0, 0, 0], from: cameraPosition, relativeTo: nil)
            
            // 添加到場景並設為活動相機
            rvc.add(camera)
            cameraEntity = camera
            
            // 保存預設位置
            defaultCameraPosition = cameraPosition
            cameraDistance = optimalDistance
            baseCameraDistance = optimalDistance  // 初始化 pinch 手勢基準距離

            // 初始化相機環繞狀態
            orbitCenter = bounds.center  // 使用模型中心作為環繞中心
            cameraAzimuth = 0.0  // 初始方位角（面向 -Z 軸）
            cameraElevation = 0.0  // 初始仰角（水平面）

            print("📸 相機位置: \(cameraPosition)")
            print("📸 最佳距離: \(optimalDistance)m")
            print("🔄 環繞中心: \(orbitCenter)")
            print("✅ 相機已創建並設為活動相機")
            print("🎥 ===== 相機設置完成 =====\n")
          } catch {
            print("載入模型失敗: \(error)")
          }
        }
        .gesture(
          tap
            .simultaneously(with: drag)
            .simultaneously(with: pinch)
        ).border(.red)
        
        // UI 控制層 - 浮動在底部
        VStack {
          Spacer()
          
          // 🎥 相機控制區域
          VStack(spacing: 12) {
            // 標題列（可點擊折疊）
            Button(action: {
              withAnimation {
                showCameraControls.toggle()
              }
            }) {
              HStack {
                Text("相機控制")
                  .font(.headline)
                  .foregroundColor(.primary)
                Spacer()
                Image(systemName: showCameraControls ? "chevron.up" : "chevron.down")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
            .buttonStyle(.plain)
            
            if showCameraControls {
              // FOV 控制（透視相機）
              VStack(spacing: 8) {
                HStack {
                  Text("視野角度 (FOV)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                  Spacer()
                  Text("\(String(format: "%.0f", cameraFOV))°")
                    .font(.caption.bold())
                    .foregroundColor(.blue)
                }
                
                Slider(value: $cameraFOV, in: 30...120, step: 1) { editing in
                  if !editing {
                    // 滑桿釋放時更新相機
                    animateCameraFOV(to: cameraFOV, duration: 0.2)
                  }
                }
                .tint(.blue)
                
                // FOV 快速預設按鈕
                HStack(spacing: 12) {
                  Button("廣角 (90°)") {
                    cameraFOV = 90.0
                    animateCameraFOV(to: 90.0)
                  }
                  .buttonStyle(.bordered)
                  .font(.caption)
                  
                  Button("標準 (60°)") {
                    cameraFOV = 60.0
                    animateCameraFOV(to: 60.0)
                  }
                  .buttonStyle(.bordered)
                  .font(.caption)
                  
                  Button("望遠 (30°)") {
                    cameraFOV = 30.0
                    animateCameraFOV(to: 30.0)
                  }
                  .buttonStyle(.bordered)
                  .font(.caption)
                }
              }
              
              Divider()
                .padding(.vertical, 4)
              
              // 距離控制
              VStack(spacing: 8) {
                HStack {
                  Text("相機距離")
                    .font(.caption)
                    .foregroundColor(.secondary)
                  Spacer()
                  Text("\(String(format: "%.2f", cameraDistance))m")
                    .font(.caption.bold())
                    .foregroundColor(.purple)
                }
                
                Slider(value: $cameraDistance, in: 0.5...3.0, step: 0.1) { editing in
                  if !editing {
                    // 滑桿釋放時更新相機
                    animateCameraDistance(to: cameraDistance, duration: 0.2)
                  }
                }
                .tint(.purple)
              }
              
              Divider()
                .padding(.vertical, 4)
              
              // 控制按鈕
              HStack(spacing: 12) {
                Button("重置相機") {
                  resetCameraView()
                }
                .buttonStyle(.bordered)
                .font(.caption)
                .foregroundColor(.orange)
                
                if let entity = focusedEntity {
                  Button("聚焦選中物件") {
                    focusOnEntity(entity)
                  }
                  .buttonStyle(.bordered)
                  .font(.caption)
                  .foregroundColor(.green)
                } else {
                  Button("聚焦選中物件") {
                    // 未選中時禁用
                  }
                  .buttonStyle(.bordered)
                  .font(.caption)
                  .foregroundColor(.gray)
                  .disabled(true)
                }
              }
            }
          }
          .padding()
          .cornerRadius(8)
          .padding(.horizontal)
          
          // 動畫控制區域
          if !animationNames.isEmpty {
            VStack(spacing: 12) {
              // 標題列（可點擊折疊）
              Button(action: {
                withAnimation {
                  showAnimationControls.toggle()
                }
              }) {
                HStack {
                  Text("動畫控制")
                    .font(.headline)
                    .foregroundColor(.primary)
                  Spacer()
                  Image(systemName: showAnimationControls ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
              }
              .buttonStyle(.plain)
              
              if showAnimationControls {
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
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
          }
          
          // base_telescope 控制區域
          if baseTelescope != nil {
            VStack(spacing: 12) {
              // 標題列（可點擊折疊）
              Button(action: {
                withAnimation {
                  showTelescopeControls.toggle()
                }
              }) {
                HStack {
                  Text("Base Telescope 控制")
                    .font(.headline)
                    .foregroundColor(.primary)
                  Spacer()
                  Image(systemName: showTelescopeControls ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
              }
              .buttonStyle(.plain)
              
              if showTelescopeControls {
                // 顯示兩個軸的旋轉角度
                VStack(spacing: 4) {
                  HStack(spacing: 16) {
                    Text("左右 (Yaw): \(String(format: "%.0f°", baseTelescopeRotation * 180 / .pi))")
                      .font(.caption)
                      .foregroundColor(.secondary)
                    
                    Text("上下 (Pitch): \(String(format: "%.0f°", baseTelescopeRotationX * 180 / .pi))")
                      .font(.caption)
                      .foregroundColor(.secondary)
                  }
                }
                
                // Y 軸控制 - 左右旋轉
                VStack(spacing: 8) {
                  Text("左右旋轉 (Yaw)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                  
                  HStack(spacing: 20) {
                    Button("◀︎ 左轉 15°") {
                      rotateBaseTelescope(by: -.pi / 12, axis: .y)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    
                    Button("左轉 5°") {
                      rotateBaseTelescope(by: -.pi / 36, axis: .y)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption2)
                    
                    Button("重置") {
                      resetBaseTelescopeRotation()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    .foregroundColor(.orange)
                    
                    Button("右轉 5°") {
                      rotateBaseTelescope(by: .pi / 36, axis: .y)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption2)
                    
                    Button("右轉 15° ▶︎") {
                      rotateBaseTelescope(by: .pi / 12, axis: .y)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                  }
                }
                
                // X 軸控制 - 上下抬頭
                VStack(spacing: 8) {
                  Text("上下抬頭 (Pitch)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                  
                  HStack(spacing: 20) {
                    Button("▼ 向下 15°") {
                      rotateBaseTelescope(by: .pi / 12, axis: .x)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    
                    Button("向下 5°") {
                      rotateBaseTelescope(by: .pi / 36, axis: .x)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption2)
                    
                    Spacer()
                      .frame(width: 60)
                    
                    Button("向上 5°") {
                      rotateBaseTelescope(by: -.pi / 36, axis: .x)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption2)
                    
                    Button("▲ 向上 15°") {
                      rotateBaseTelescope(by: -.pi / 12, axis: .x)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                  }
                }
                
                // fly_telescope 綁定控制（只在找到 fly_telescope 時顯示）
                if flyTelescope != nil {
                  Divider()
                    .padding(.vertical, 4)
                  
                  VStack(spacing: 8) {
                    HStack {
                      Text("Fly Telescope 綁定")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                      
                      Spacer()
                      
                      Text(isFlyBoundToBase ? "已綁定" : "未綁定")
                        .font(.caption)
                        .foregroundColor(isFlyBoundToBase ? .green : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isFlyBoundToBase ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                        .cornerRadius(4)
                    }
                    
                    if isFlyBoundToBase {
                      Button("🔓 解除綁定 fly_telescope") {
                        unbindFlyTelescopeFromBase()
                      }
                      .buttonStyle(.bordered)
                      .font(.caption)
                      .foregroundColor(.red)
                    } else {
                      Button("🔗 綁定 fly_telescope") {
                        bindFlyTelescopeToBase()
                      }
                      .buttonStyle(.bordered)
                      .font(.caption)
                      .foregroundColor(.green)
                    }
                    
                    Text(isFlyBoundToBase ? "旋轉 base 會帶動 fly 一起旋轉" : "點擊綁定後，fly 將跟隨 base 旋轉")
                      .font(.caption2)
                      .foregroundColor(.secondary)
                  }
                }
              }
            }
            .padding()
            .background(Color.green.opacity(0.15))
            .cornerRadius(8)
            .padding(.horizontal)
          }
          
          // 點擊資訊顯示
          if let entity = tappedEntity, let coordinates = tapCoordinates {
            VStack(alignment: .leading, spacing: 8) {
              // 標題列（可點擊折疊）
              Button(action: {
                withAnimation {
                  showEntityInfo.toggle()
                }
              }) {
                HStack {
                  Text("已選中物件")
                    .font(.headline)
                    .foregroundColor(.primary)
                  Spacer()
                  Image(systemName: showEntityInfo ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
              }
              .buttonStyle(.plain)
              
              if showEntityInfo {
                // 清除按鈕
                HStack {
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

        // 🔄 重置相機按鈕 - 浮動在右上角
        if focusedEntity != nil {
          VStack {
            HStack {
              Spacer()

              Button(action: {
                resetCameraView()
              }) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                  .font(.title2)
                  .foregroundColor(.white)
                  .padding(12)
                  .background(Color.orange.opacity(0.8))
                  .clipShape(Circle())
                  .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
              }
              .buttonStyle(.plain)
              .padding(.trailing, 20)
              .padding(.top, 20)
            }
            Spacer()
          }
        }
      }
    }
  }
}

#Preview("TestRealityKit") {
  TestRealityKit()
}
