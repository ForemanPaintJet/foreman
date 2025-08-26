//
//  SplashView.swift
//  foreman
//
//  Created by Claude on 2025/8/26.
//

import ComposableArchitecture
import OSLog
import SwiftUI

@ViewAction(for: SplashFeature.self)
struct SplashView: View {
  @Bindable var store: StoreOf<SplashFeature>
  let namespace: Namespace.ID
  let isTransitioning: Bool
  
  private let logger = Logger(subsystem: "foreman", category: "SplashView")
  
  var body: some View {
    ZStack {
      // 背景
      Rectangle()
        .fill(.orange.gradient)
        .ignoresSafeArea()
        .opacity(isTransitioning ? 0 : 1)
      
      VStack(spacing: 40) {
        // App Logo/Icon
        Image("logo")
          .renderingMode(.template)
          .foregroundColor(.white)
          .scaleEffect(isTransitioning ? 1 : store.scaleAmount * 1.2) // 調整最終大小
          .rotationEffect(.degrees(90)) // 固定 90 度
          .matchedGeometryEffect(id: "videoIcon", in: namespace)
        
        // App Title
        Text("FOREMAN TECH")
          .font(.title)
          .fontWeight(.bold)
          .foregroundColor(.white)
          .opacity(isTransitioning ? 0 : store.animationProgress)
          .matchedGeometryEffect(id: "titleText", in: namespace)
      }
      .padding()
    }
    .task {
      logger.info("SplashView task started")
      send(.task)
    }
  }
}

#Preview {
  @Namespace var namespace
  return SplashView(
    store: .init(
      initialState: SplashFeature.State(),
      reducer: {
        SplashFeature()
      }),
    namespace: namespace,
    isTransitioning: false
  )
}
