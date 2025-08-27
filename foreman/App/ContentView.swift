import SwiftUI

struct ContentView: View {
    var body: some View {
        RootView(
            store: .init(
                initialState: RootFeature.State(),
                reducer: {
                    RootFeature()
                }))
    }
}

#Preview {
    ContentView()
}
