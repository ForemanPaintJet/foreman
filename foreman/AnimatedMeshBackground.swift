import ForemanThemeCore
import SwiftUI

// MARK: - Animated Mesh Background

/// A reusable animated mesh gradient background that can be used across the app
struct AnimatedMeshBackground: View {
    @State private var animate = false
    
    // Configuration
    private let themeConfig: ThemeConfiguration<DynamicTheme>
    private let meshWidth: Int
    private let meshHeight: Int
    
    // MARK: - Initializers
    
    /// Creates a background with default orange theme
    init() {
        self.themeConfig = ThemeFactory.orange()
        // Default: 12 colors = 3x4 mesh
        self.meshWidth = 3
        self.meshHeight = 4
    }
    
    /// Creates a background with custom theme configuration
    init(themeConfig: ThemeConfiguration<DynamicTheme>) {
        self.themeConfig = themeConfig
        // Calculate mesh dimensions based on number of colors
        let colorCount = themeConfig.meshColors.count
        let dimensions = Self.calculateMeshDimensions(for: colorCount)
        self.meshWidth = dimensions.width
        self.meshHeight = dimensions.height
    }
    
    /// Creates a background with custom theme and mesh dimensions
    init(
        themeConfig: ThemeConfiguration<DynamicTheme>,
        meshWidth: Int,
        meshHeight: Int
    ) {
        self.themeConfig = themeConfig
        self.meshWidth = meshWidth
        self.meshHeight = meshHeight
    }
    
    // MARK: - Body
    
    var body: some View {
        MeshGradient(
            width: meshWidth,
            height: meshHeight,
            points: generateMeshPoints(),
            colors: themeConfig.meshColors
        )
        .hueRotation(
            .degrees(
                animate ? themeConfig.hueRotationRange.max : themeConfig.hueRotationRange.min
            )
        )
        .animation(
            .easeInOut(duration: themeConfig.animationDuration)
                .repeatForever(autoreverses: true),
            value: animate
        )
        .onAppear {
            animate = true
        }
        .ignoresSafeArea(.all)
    }
    
    // MARK: - Private Methods
    
    /// Calculates optimal mesh dimensions based on number of colors
    private static func calculateMeshDimensions(for colorCount: Int) -> (width: Int, height: Int) {
        // ForemanThemeCore provides 12 colors in a 3x4 arrangement
        switch colorCount {
        case 12:
            return (width: 3, height: 4)
        case 9:
            return (width: 3, height: 3)
        case 6:
            return (width: 2, height: 3)
        case 4:
            return (width: 2, height: 2)
        case 16:
            return (width: 4, height: 4)
        case 20:
            return (width: 4, height: 5)
        default:
            // For any other count, try to make it roughly rectangular
            let sqrt = Int(sqrt(Double(colorCount)))
            let width = sqrt
            let height = (colorCount + width - 1) / width // Ceiling division
            return (width: width, height: height)
        }
    }
    
    /// Generates mesh points based on dimensions to match color count
    private func generateMeshPoints() -> [SIMD2<Float>] {
        // Generate points in row-major order to match color array
        
        (0..<meshHeight).flatMap { y in
            (0..<meshWidth).map { x in
                let fx = Float(x) / Float(meshWidth - 1)
                let fy = Float(y) / Float(meshHeight - 1)
                return SIMD2(fx, fy)
            }
        }
    }
}

// MARK: - Convenience Extensions

extension AnimatedMeshBackground {
    /// Creates a background with a specific theme (auto-calculates mesh dimensions)
    static func withTheme(_ theme: AppTheme, variant: ThemeVariant = .vibrant) -> AnimatedMeshBackground {
        let config: ThemeConfiguration<DynamicTheme>
        switch theme {
        case .orange:
            config = ThemeFactory.orange(variant: variant)
        case .green:
            config = ThemeFactory.green(variant: variant)
        case .blue:
            config = ThemeFactory.blue(variant: variant)
        }
        return AnimatedMeshBackground(themeConfig: config)
    }
    
    /// Creates a background with a custom base color (auto-calculates mesh dimensions)
    static func withColor(_ color: Color, variant: ThemeVariant = .vibrant) -> AnimatedMeshBackground {
        let config = ThemeFactory.dynamic(baseColor: color, variant: variant)
        return AnimatedMeshBackground(themeConfig: config)
    }
    
    /// Creates a full screen background with higher mesh density
    static func fullScreen(theme: AppTheme = .orange, variant: ThemeVariant = .vibrant) -> AnimatedMeshBackground {
        let config: ThemeConfiguration<DynamicTheme>
        switch theme {
        case .orange:
            config = ThemeFactory.orange(variant: variant)
        case .green:
            config = ThemeFactory.green(variant: variant)
        case .blue:
            config = ThemeFactory.blue(variant: variant)
        }
        // Use higher density for full screen (4x5 = 20 points for 12 colors)
        return AnimatedMeshBackground(themeConfig: config, meshWidth: 4, meshHeight: 5)
    }
}

// MARK: - Usage Examples in Comments

/*
 Usage Examples:
 
 // Default background (auto-calculated mesh based on 12 colors = 3x4)
 AnimatedMeshBackground()
 
 // Auto-calculated mesh dimensions based on theme colors
 AnimatedMeshBackground.withTheme(.green, variant: .dark)
 
 // Custom color (auto-calculated mesh)
 AnimatedMeshBackground.withColor(.purple)
 
 // Full screen with higher density (4x5 mesh for smoother gradients)
 AnimatedMeshBackground.fullScreen()
 
 // Manual mesh control (if you need specific dimensions)
 AnimatedMeshBackground(
     themeConfig: ThemeFactory.orange(),
     meshWidth: 3,
     meshHeight: 4
 )
 
 // In a view as background:
 ZStack {
     AnimatedMeshBackground() // Automatically uses 3x4 for 12 colors
     
     VStack {
         Text("Your content here")
     }
 }
 
 Note: The mesh dimensions are automatically calculated based on the number of
 colors in themeConfig.meshColors. ForemanThemeCore provides 12 colors, so
 the optimal mesh is 3x4 (12 grid squares requiring 4x5 = 20 points).
 */

// MARK: - Preview Examples

#Preview("Default Background") {
    AnimatedMeshBackground()
}

#Preview("Full Screen Background") {
    AnimatedMeshBackground.fullScreen()
}

#Preview("Green Background") {
    AnimatedMeshBackground.withTheme(.green)
}

#Preview("Custom Color Background") {
    AnimatedMeshBackground.withColor(.purple)
}

#Preview("With Content") {
    ZStack {
        AnimatedMeshBackground()
        
        VStack(spacing: 20) {
            Text("Foreman")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Beautiful mesh gradient background")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}
