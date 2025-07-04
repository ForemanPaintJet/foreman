//
//  ContentView.swift
//  foreman
//
//  Created by Jed Lu on 2025/7/3.
//

import ComposableArchitecture
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            WebRTCSocketView(
                store: Store(
                    initialState: WebRTCSocketFeature.State(),
                    reducer: { WebRTCSocketFeature() }
                )
            )
            .tabItem {
                Image(systemName: "network")
                Text("WebRTC Socket")
            }

            // Original content as a placeholder
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")
            }
            .padding()
            .tabItem {
                Image(systemName: "house")
                Text("Home")
            }
        }
    }
}

#Preview {
    ContentView()
}
