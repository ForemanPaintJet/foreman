# ForemanThemeCore

A lightweight, protocol-based theme system core for SwiftUI applications. This package provides the infrastructure for creating custom themes without dictating specific color schemes.

## Philosophy

This package follows the **"Framework, not Themes"** approach:
- ✅ Provides the protocol and tools
- ✅ Lets you define your own brand colors
- ✅ No assumptions about your design system
- ✅ Maximum flexibility and customization

## Features

- 🎯 **Protocol-based** - Define themes that fit your brand
- 🎨 **Flexible variants** - Light, Dark, Vibrant modes
- ✨ **Mesh gradient support** - Built-in support for SwiftUI mesh gradients
- ⚡ **Performance optimized** - Minimal overhead
- 🧪 **Fully tested** - Comprehensive test coverage
- 📚 **Well documented** - Clear API with examples

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(path: "Packages/ForemanThemeCore")
]
```

Or in Xcode: File → Add Package Dependencies → Add Local → Select `Packages/ForemanThemeCore`

## Quick Start

### 1. Define Your Theme

```swift
import ForemanThemeCore
import SwiftUI

struct MyBrandTheme: ColorTheme {
    // Define your brand's color palette
    let brightColor = Color(red: 1.0, green: 0.6, blue: 0.2)    // Your bright accent
    let pureColor = Color(red: 1.0, green: 0.5, blue: 0.0)     // Primary brand color
    let deepColor = Color(red: 0.8, green: 0.4, blue: 0.1)     // Deep variant
    let lightColor = Color(red: 1.0, green: 0.8, blue: 0.4)    // Light variant
    let darkColor = Color(red: 0.6, green: 0.3, blue: 0.1)     // Dark variant
    let mediumColor = Color(red: 0.9, green: 0.5, blue: 0.2)   // Medium variant
    let pasteltColor = Color(red: 1.0, green: 0.9, blue: 0.6)  // Pastel variant
    let burntColor = Color(red: 0.7, green: 0.3, blue: 0.1)    // Burnt/muted
    let warmColor = Color(red: 0.95, green: 0.6, blue: 0.3)    // Warm variant
    let goldenColor = Color(red: 1.0, green: 0.7, blue: 0.2)   // Golden accent
    let deepBurntColor = Color(red: 0.5, green: 0.2, blue: 0.05) // Deep burnt
    
    // Optional: Customize semantic mappings
    var primary: Color { pureColor }
    var secondary: Color { warmColor }
    var accent: Color { goldenColor }
    var background: Color { lightColor }
}
```

### 2. Create Theme Configuration

```swift
let themeConfig = ThemeConfiguration(
    colorTheme: MyBrandTheme(),
    variant: .vibrant
)

// Or use the factory helper
let themeConfig = ThemeFactory.configuration(
    for: MyBrandTheme(),
    variant: .light
)
```

### 3. Use in Your Views

```swift
struct MyView: View {
    private let theme = ThemeConfiguration(colorTheme: MyBrandTheme())
    
    var body: some View {
        VStack {
            Text("Hello")
                .foregroundColor(theme.primary)
            
            Rectangle()
                .fill(theme.accent)
                .frame(height: 100)
        }
        .background(theme.background)
    }
}
```

### 4. Animated Mesh Gradients

```swift
struct AnimatedBackground: View {
    @State private var animate = false
    private let theme = ThemeConfiguration(colorTheme: MyBrandTheme())
    
    var body: some View {
        MeshGradient(
            width: 3,
            height: 4,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.33], [0.5, 0.33], [1, 0.33],
                [0, 0.67], [0.5, 0.67], [1, 0.67],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: theme.meshColors
        )
        .hueRotation(.degrees(animate ? theme.hueRotationRange.max : theme.hueRotationRange.min))
        .animation(.easeInOut(duration: theme.animationDuration).repeatForever(autoreverses: true), value: animate)
        .onAppear { animate = true }
    }
}
```

## Advanced Usage

### Theme Variants

```swift
// Light variant - optimized for light backgrounds
let lightTheme = ThemeConfiguration(colorTheme: MyBrandTheme(), variant: .light)

// Dark variant - optimized for dark backgrounds  
let darkTheme = ThemeConfiguration(colorTheme: MyBrandTheme(), variant: .dark)

// Vibrant variant - full color intensity
let vibrantTheme = ThemeConfiguration(colorTheme: MyBrandTheme(), variant: .vibrant)
```

### Custom Animation Settings

```swift
let customTheme = ThemeConfiguration(
    colorTheme: MyBrandTheme(),
    variant: .vibrant,
    animationDuration: 12.0,        // Slower animations
    hueRotationIntensity: 30.0      // More dramatic hue shifts
)
```

### Multiple Themes

```swift
struct OrangeTheme: ColorTheme { /* orange colors */ }
struct BlueTheme: ColorTheme { /* blue colors */ }
struct GreenTheme: ColorTheme { /* green colors */ }

// Easy switching
@State private var currentTheme: any ColorTheme = OrangeTheme()

var themeConfig: ThemeConfiguration<any ColorTheme> {
    ThemeConfiguration(colorTheme: currentTheme)
}
```

## API Reference

### ColorTheme Protocol

```swift
protocol ColorTheme {
    // Required: Define your color palette
    var brightColor: Color { get }
    var pureColor: Color { get }
    var deepColor: Color { get }
    var lightColor: Color { get }
    var darkColor: Color { get }
    var mediumColor: Color { get }
    var pasteltColor: Color { get }
    var burntColor: Color { get }
    var warmColor: Color { get }
    var goldenColor: Color { get }
    var deepBurntColor: Color { get }
    
    // Optional: Customize these or use defaults
    var meshGradientColors: [Color] { get }
    var primary: Color { get }
    var secondary: Color { get }
    var accent: Color { get }
    var background: Color { get }
}
```

### ThemeVariant

```swift
enum ThemeVariant {
    case light      // Optimized for light backgrounds
    case dark       // Optimized for dark backgrounds  
    case vibrant    // Full color intensity
}
```

### ThemeConfiguration

Combines your theme with variant and animation settings:

```swift
struct ThemeConfiguration<T: ColorTheme> {
    let colorTheme: T
    let variant: ThemeVariant
    let animationDuration: Double
    let hueRotationIntensity: Double
    
    // Computed properties
    var meshColors: [Color] { get }
    var hueRotationRange: (min: Double, max: Double) { get }
    
    // Convenience accessors for all colors
    var primary: Color { get }
    var brightColor: Color { get }
    // ... etc
}
```

## Example Themes

Here are some example themes to get you started:

<details>
<summary>Ocean Theme</summary>

```swift
struct OceanTheme: ColorTheme {
    let brightColor = Color(red: 0.1, green: 0.7, blue: 1.0)
    let pureColor = Color(red: 0.0, green: 0.5, blue: 0.8)
    let deepColor = Color(red: 0.0, green: 0.3, blue: 0.6)
    let lightColor = Color(red: 0.6, green: 0.9, blue: 1.0)
    let darkColor = Color(red: 0.0, green: 0.2, blue: 0.4)
    let mediumColor = Color(red: 0.2, green: 0.6, blue: 0.9)
    let pasteltColor = Color(red: 0.8, green: 0.95, blue: 1.0)
    let burntColor = Color(red: 0.0, green: 0.25, blue: 0.5)
    let warmColor = Color(red: 0.3, green: 0.7, blue: 0.9)
    let goldenColor = Color(red: 0.2, green: 0.8, blue: 1.0)
    let deepBurntColor = Color(red: 0.0, green: 0.15, blue: 0.3)
}
```
</details>

<details>
<summary>Forest Theme</summary>

```swift
struct ForestTheme: ColorTheme {
    let brightColor = Color(red: 0.3, green: 0.9, blue: 0.3)
    let pureColor = Color(red: 0.2, green: 0.7, blue: 0.2)
    let deepColor = Color(red: 0.1, green: 0.5, blue: 0.1)
    let lightColor = Color(red: 0.6, green: 0.95, blue: 0.6)
    let darkColor = Color(red: 0.1, green: 0.4, blue: 0.1)
    let mediumColor = Color(red: 0.3, green: 0.6, blue: 0.3)
    let pasteltColor = Color(red: 0.8, green: 0.98, blue: 0.8)
    let burntColor = Color(red: 0.2, green: 0.4, blue: 0.1)
    let warmColor = Color(red: 0.4, green: 0.8, blue: 0.4)
    let goldenColor = Color(red: 0.6, green: 0.9, blue: 0.3)
    let deepBurntColor = Color(red: 0.1, green: 0.3, blue: 0.05)
}
```
</details>

## Requirements

- iOS 15.0+
- macOS 12.0+
- watchOS 8.0+
- tvOS 15.0+
- Swift 5.9+

## License

MIT License
