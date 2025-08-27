//
//  RootView.swift
//  foreman
//
//  Created by Claude on 2025/8/26.
//

import ComposableArchitecture
import SwiftUI

struct RootView: View {
  let store: StoreOf<RootFeature>
  @Namespace private var videoIconNamespace
  
  init(store: StoreOf<RootFeature>) {
    self.store = store
  }
  
  var body: some View {
    ZStack {      
      // WebRTC View
      if let webRTCStore = store.scope(state: \.webRTCMqtt, action: \.webRTCMqtt) {
        WebRTCMqttView(
          store: webRTCStore,
          namespace: videoIconNamespace
        ).transition(.slide)
      }
      
      // Splash View 
      if let splashStore = store.scope(state: \.splash, action: \.splash) {
        SplashView(
          store: splashStore,
          namespace: videoIconNamespace
        )
      }
    }.task {
        store.send(.task)
    }
  }
}

#Preview {
  RootView(
    store: .init(
      initialState: RootFeature.State(),
      reducer: {
        RootFeature()
      }))
}
