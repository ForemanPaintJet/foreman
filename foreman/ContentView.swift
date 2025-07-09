import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            // Use the AnimatedMeshBackground as the app background
            AnimatedMeshBackground()
            
            // Your main app content goes here
//            mainContent
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 30) {
            // App title
            VStack(spacing: 10) {
                Text("Foreman")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Dynamic Theme System")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Sample content
            VStack(spacing: 20) {
                Text("Welcome to your app!")
                    .font(.title3)
                    .foregroundColor(.white)
                
                Text("This beautiful animated mesh gradient background can be used throughout your app.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .background(Color.black.opacity(0.2))
            .cornerRadius(16)
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
