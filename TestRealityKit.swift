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

    // 旋轉靈敏度
    let ratio: Float = 0.005

    var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // 水平拖曳 → Y 軸旋轉
                rotationY += Float(value.translation.width) * ratio
                group.orientation = simd_quatf(angle: rotationY, axis: [0, 1, 0])
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
        print("\(indent)- \(entity.name.isEmpty ? "<unnamed>" : entity.name)")
        for child in entity.children {
            printEntityHierarchy(child, depth: depth + 1)
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
                    
                    // 設定動畫
                    setupAnimations()
                } catch {
                    print("載入模型失敗: \(error)")
                }
            }
            .gesture(
                drag
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
            }
        }
    }
}

#Preview("TestRealityKit") {
  TestRealityKit()
}
