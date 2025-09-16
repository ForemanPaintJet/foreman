//
//  RotatingGradientBorderView.swift
//  foreman
//
//  Created by Claude on 2025/9/15.
//

import SwiftUI

struct RotatingGradientBorderView<Content: View>: View {
  let isActive: Bool
  let content: () -> Content
  
  @State private var rotation: Double = 0
  @State private var isAnimating: Bool = false
  
  let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect() // 60fps
  
  var animatedGradient: AngularGradient {
    AngularGradient(
      colors: [.green, .blue, .purple, .pink, .orange, .green],
      center: .center,
      startAngle: .degrees(rotation),
      endAngle: .degrees(rotation + 360)
    )
  }
  
  var staticBorder: Color {
    .secondary
  }
  
  var body: some View {
    content()
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(
            animatedGradient,
            lineWidth: isActive ? 8 : 0
          )
      )
      .onReceive(timer) { _ in
        if isActive && isAnimating {
          rotation += 3 // 每幀旋轉3度，約1秒一圈
          if rotation >= 360 {
            rotation = 0
          }
        }
      }
      .onChange(of: isActive) { _, newValue in
        if newValue {
          isAnimating = true
        } else {
          isAnimating = false
          withAnimation(.easeOut(duration: 0.3)) {
            rotation = 0
          }
        }
      }
      .onAppear {
        if isActive {
          isAnimating = true
        }
      }
      .transition(.scale(scale: 0.8).combined(with: .opacity))
  }
}

#Preview {
  VStack(spacing: 20) {
    Text("Static Border (Idle)")
      .font(.title2)
    
    RotatingGradientBorderView(isActive: false) {
      VStack(spacing: 12) {
        Text("Idle State")
          .font(.headline)
          .foregroundColor(.primary)
        
        Rectangle()
          .fill(.gray.gradient)
          .frame(width: 100, height: 100)
          .cornerRadius(8)
      }
      .padding(16)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    Text("Animated Border (Active)")
      .font(.title2)
    
    RotatingGradientBorderView(isActive: true) {
      VStack(spacing: 12) {
        Text("Active State")
          .font(.headline)
          .foregroundColor(.primary)
        
        Rectangle()
          .fill(.blue.gradient)
          .frame(width: 100, height: 100)
          .cornerRadius(8)
      }
      .padding(16)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
  }
  .padding()
}
