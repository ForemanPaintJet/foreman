import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            // Use the AnimatedMeshBackground as the app background
            AnimatedMeshBackground()
            
            // Your main app content goes here
            WebRTCSocketView(store: .init(initialState: WebRTCSocketFeature.State(), reducer: {
                WebRTCSocketFeature()
            }))
        }
    }
}

#Preview {
    ContentView()
}
