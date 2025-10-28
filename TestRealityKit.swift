//
//  TestRealityKit.swift
//  foreman
//
//  Created by Jed Lu on 2025/10/27.
//

import SwiftUI
import RealityKit

struct TestRealityKit: View {
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
    @State private var rootEntity: Entity?

    // 旋轉靈敏度
    let ratio: Float = 0.005

    var drag: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                // 水平拖曳 → Y 軸旋轉
                rotationY += Float(value.translation.width) * ratio
                group.orientation = simd_quatf(angle: rotationY, axis: [0, 1, 0])
            }
    }
    
    var tap: some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                // 只有在拖拽距離很小時才視為點擊
                let distance = sqrt(value.translation.width * value.translation.width + value.translation.height * value.translation.height)
                if distance < 10 {
                    handleTap(at: value.location)
                }
            }
    }

    var pinch: some Gesture {
        MagnificationGesture()
            .onChanged { mag in
                print("Pinch detected: \(mag)")
                let newScale = currentScale * Float(mag)
                scale = min(max(newScale, 0.5), 2.0)
                print("New scale: \(scale)")
                group.scale = SIMD3(repeating: scale)
            }
            .onEnded { _ in
                print("Pinch ended, final scale: \(scale)")
                currentScale = scale
            }
    }

    
    private func setupAnimations() {
        guard let biplane = biplane else { return }
        
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
        guard let biplane = biplane,
              let animationIndex = animationNames.firstIndex(of: selectedAnimation),
              animationIndex < availableAnimations.count else { 
            print("無法播放動畫：\(selectedAnimation)")
            return 
        }
        
        let animation = availableAnimations[animationIndex]
        biplane.playAnimation(animation.repeat())
        isPlaying = true
        print("播放動畫：\(selectedAnimation)")
    }
    
    private func stopAnimation() {
        guard let biplane = biplane else { return }
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
        guard let biplane = biplane else {
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
    
    private func handleTap(at location: CGPoint) {
        guard let root = rootEntity else {
            print("⚠️ 沒有可用的根實體進行點擊處理")
            return
        }
        
        let tappedEntity = findTappedEntity(in: root, at: location)
        
        if let entity = tappedEntity {
            let entityPath = getEntityPath(entity)
            print("👆 點擊實體: \(entity.name.isEmpty ? "<unnamed>" : entity.name)")
            print("🔗 實體路徑: \(entityPath)")
            print("🆔 實體ID: \(entity.id)")
            print("📍 座標: \(entity.position(relativeTo: nil))")
            
            self.tappedEntity = entity
            self.tapCoordinates = entity.position(relativeTo: nil)
            
            // 顯示所有子實體
            print("👶 子實體數量: \(entity.children.count)")
            for (index, child) in entity.children.enumerated() {
                print("  [\(index)] \(child.name.isEmpty ? "<unnamed>" : child.name)")
            }
        } else {
            print("👆 點擊位置沒有找到實體")
            self.tappedEntity = nil
            self.tapCoordinates = nil
        }
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
    
    private func findTappedEntity(in entity: Entity, at location: CGPoint) -> Entity? {
        var foundEntities: [Entity] = []
        collectTappableEntities(in: entity, results: &foundEntities)
        
        // 目前返回第一個找到的實體，之後可以用更精確的射線檢測
        // 優先返回有明確名稱的實體
        if let namedEntity = foundEntities.first(where: { !$0.name.isEmpty }) {
            return namedEntity
        }
        
        return foundEntities.first
    }
    
    private func collectTappableEntities(in entity: Entity, results: inout [Entity]) {
        // 只要有 CollisionComponent 就可以點擊
        if entity.components.has(CollisionComponent.self) {
            results.append(entity)
        }
        
        for child in entity.children {
            collectTappableEntities(in: child, results: &results)
        }
    }
    
    private func configureEntityForTap(_ entity: Entity) {
        // 為重要的命名實體添加碰撞檢測，即使它們沒有 ModelComponent
        let importantEntities = ["wheels", "propeller", "pilot", "body", "wings", "fastener"]
        
        for child in entity.children {
            configureEntityForTap(child)
        }
        
        // 為有 ModelComponent 的實體配置
        if entity.components.has(ModelComponent.self) {
            let bounds = entity.visualBounds(relativeTo: nil)
            let size = bounds.extents
            
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
            
            entity.components[InputTargetComponent.self] = InputTargetComponent(allowedInputTypes: .all)
            
            print("✅ 已為實體 '\(entity.name.isEmpty ? "<unnamed>" : entity.name)' 配置點擊檢測 [ModelComponent]")
        }
        // 為重要的命名實體添加碰撞檢測（即使沒有 ModelComponent）
        else if importantEntities.contains(entity.name) {
            // 計算子實體的總邊界
            let bounds = entity.visualBounds(relativeTo: nil)
            let size = bounds.extents
            
            if size.x > 0 && size.y > 0 && size.z > 0 {
                let shape = ShapeResource.generateBox(size: size)
                entity.components[CollisionComponent.self] = CollisionComponent(
                    shapes: [shape],
                    mode: .default,
                    filter: .default
                )
                
                entity.components[InputTargetComponent.self] = InputTargetComponent(allowedInputTypes: .all)
                
                print("✅ 已為命名實體 '\(entity.name)' 配置點擊檢測 [NamedEntity]")
            }
        }
    }

    var body: some View {
        ZStack {
            // 3D 模型檢視 - 佔據全螢幕接收手勢
            RealityView { rvc in
                do {
                    let loadedBiplane = try Entity.load(named: "toy_biplane_realistic")
                    biplane = loadedBiplane
                    group.addChild(loadedBiplane)
                    rvc.add(group)
                    
                    // 配置點擊檢測
                    configureEntityForTap(loadedBiplane)
                    rootEntity = loadedBiplane
                    
                    // 設定動畫
                    setupAnimations()
                    
                    // 打印詳細模型資訊
                    printDetailedModelInfo()
                } catch {
                    print("載入模型失敗: \(error)")
                }
            }
            .gesture(
                tap
                    .simultaneously(with: drag)
                    .simultaneously(with: pinch)
            )
            
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
                            .onChange(of: selectedAnimation) { newValue in
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
            }
        }
    }
}

#Preview("TestRealityKit") {
  TestRealityKit()
}
