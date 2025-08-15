import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            // Use the AnimatedMeshBackground as the app background
            Rectangle()
                .fill(.orange.gradient)
                .ignoresSafeArea()
            //            AnimatedMeshBackground()

            //            WebRTCSocketView(store: .init(initialState: WebRTCSocketFeature.State(), reducer: {
            //                WebRTCSocketFeature()
            //            }))

            // Your main app content goes here
            WebRTCMqttView(
                store: .init(
                    initialState: WebRTCMqttFeature.State(),
                    reducer: {
                        WebRTCMqttFeature()
                    }))
        }
    }
}

#Preview {
    ContentView()
}
