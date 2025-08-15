//
//  ForemanThemeCore.swift
//  ForemanThemeCore
//
//  Created by Theme System on 2025/7/9.
//

import SwiftUI

// MARK: - Color Extensions

extension Color {
    /// Adjusts color properties for dynamic theme generation
    public func adjust(
        hueOffset: Double = 0, saturationMultiplier: Double = 1.0,
        brightnessMultiplier: Double = 1.0
    ) -> Color {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        #if os(iOS) || os(tvOS) || os(watchOS)
            let uiColor = UIColor(self)
            uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

            let newHue = fmod(h + CGFloat(hueOffset), 1.0)
            let newS = min(max(s * saturationMultiplier, 0), 1)
            let newB = min(max(b * brightnessMultiplier, 0), 1)

            return Color(hue: newHue, saturation: newS, brightness: newB)
        #elseif os(macOS)
            let nsColor = NSColor(self)
            // Convert to RGB color space first to ensure compatibility
            if let rgbColor = nsColor.usingColorSpace(.sRGB) {
                rgbColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            } else {
                // Fallback: try converting to device RGB first
                if let deviceRGB = nsColor.usingColorSpace(.deviceRGB) {
                    deviceRGB.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
                } else {
                    // Final fallback: return original color
                    return self
                }
            }

            let newHue = fmod(h + CGFloat(hueOffset), 1.0)
            let newS = min(max(s * saturationMultiplier, 0), 1)
            let newB = min(max(b * brightnessMultiplier, 0), 1)

            return Color(hue: newHue, saturation: newS, brightness: newB)
        #else
            // Other platforms - return original color
            return self
        #endif
    }
}

// MARK: - Core Theme Protocol

/// Protocol defining the structure for color themes
/// Implement this protocol to create your own custom themes
public protocol ColorTheme {
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

    // Derived properties - these define the semantic roles
    var meshGradientColors: [Color] { get }
    var primary: Color { get }
    var secondary: Color { get }
    var accent: Color { get }
    var background: Color { get }
}

// MARK: - Dynamic Theme Implementation

/// A dynamic theme that generates all color variations from a single base color
public struct DynamicTheme: ColorTheme {
    public let baseColor: Color

    public init(baseColor: Color) {
        self.baseColor = baseColor
    }

    // Auto-generated color variations based on your provided implementation
    public var brightColor: Color { baseColor.adjust(brightnessMultiplier: 1.3) }
    public var pureColor: Color { baseColor }
    public var deepColor: Color { baseColor.adjust(brightnessMultiplier: 0.7) }
    public var lightColor: Color {
        baseColor.adjust(saturationMultiplier: 0.4, brightnessMultiplier: 1.5)
    }
    public var darkColor: Color {
        baseColor.adjust(saturationMultiplier: 1.2, brightnessMultiplier: 0.4)
    }
    public var mediumColor: Color {
        baseColor.adjust(saturationMultiplier: 0.8, brightnessMultiplier: 1.1)
    }
    public var pasteltColor: Color {
        baseColor.adjust(saturationMultiplier: 0.3, brightnessMultiplier: 1.2)
    }
    public var burntColor: Color { baseColor.adjust(hueOffset: -0.05, brightnessMultiplier: 0.6) }
    public var warmColor: Color { baseColor.adjust(hueOffset: 0.08, saturationMultiplier: 0.8) }
    public var goldenColor: Color {
        baseColor.adjust(hueOffset: 0.15, saturationMultiplier: 1.1, brightnessMultiplier: 1.1)
    }
    public var deepBurntColor: Color {
        baseColor.adjust(hueOffset: -0.08, saturationMultiplier: 1.1, brightnessMultiplier: 0.5)
    }
}

// MARK: - Default Implementation Helpers

extension ColorTheme {
    /// Default mesh gradient implementation using all colors
    public var meshGradientColors: [Color] {
        [
            brightColor, pureColor, deepColor,
            lightColor, darkColor, mediumColor,
            pasteltColor, burntColor, warmColor,
            pureColor, deepBurntColor, goldenColor,
        ]
    }

    /// Default semantic color mappings
    public var primary: Color { pureColor }
    public var secondary: Color { warmColor }
    public var accent: Color { goldenColor }
    public var background: Color { lightColor }
}

// MARK: - Theme Variants

/// Different visual variants for themes that modify how colors are combined
public enum ThemeVariant: CaseIterable {
    case light
    case dark
    case vibrant

    /// Generates mesh colors optimized for the variant
    public func meshColors<T: ColorTheme>(for theme: T) -> [Color] {
        switch self {
        case .light:
            return [
                theme.lightColor, theme.pasteltColor, theme.lightColor,
                theme.pasteltColor, theme.goldenColor, theme.pasteltColor,
                theme.lightColor, theme.warmColor, theme.lightColor,
                theme.pasteltColor, theme.goldenColor, theme.warmColor,
            ]
        case .dark:
            return [
                theme.deepColor, theme.burntColor, theme.deepColor,
                theme.darkColor, theme.deepBurntColor, theme.darkColor,
                theme.burntColor, theme.deepBurntColor, theme.burntColor,
                theme.deepColor, theme.darkColor, theme.burntColor,
            ]
        case .vibrant:
            return theme.meshGradientColors
        }
    }

    /// Animation intensity for the variant
    public var animationIntensity: Double {
        switch self {
        case .light: return 8
        case .dark: return 12
        case .vibrant: return 20
        }
    }

    /// Suggested animation duration for the variant
    public var suggestedAnimationDuration: Double {
        switch self {
        case .light: return 10.0
        case .dark: return 6.0
        case .vibrant: return 8.0
        }
    }
}

// MARK: - Theme Configuration

/// Configuration wrapper that combines a theme with its variant and animation settings
public struct ThemeConfiguration<T: ColorTheme> {
    public let colorTheme: T
    public let variant: ThemeVariant
    public let animationDuration: Double
    public let hueRotationIntensity: Double

    public init(
        colorTheme: T,
        variant: ThemeVariant = .vibrant,
        animationDuration: Double = 8.0,
        hueRotationIntensity: Double = 20.0
    ) {
        self.colorTheme = colorTheme
        self.variant = variant
        self.animationDuration = animationDuration
        self.hueRotationIntensity = hueRotationIntensity
    }

    /// Mesh colors for the current variant
    public var meshColors: [Color] {
        variant.meshColors(for: colorTheme)
    }

    /// Hue rotation range for animations
    public var hueRotationRange: (min: Double, max: Double) {
        let half = hueRotationIntensity / 2
        return (-half, half)
    }

    // MARK: - Convenience Accessors

    public var primary: Color { colorTheme.primary }
    public var secondary: Color { colorTheme.secondary }
    public var accent: Color { colorTheme.accent }
    public var background: Color { colorTheme.background }

    // MARK: - Direct Color Access

    public var brightColor: Color { colorTheme.brightColor }
    public var pureColor: Color { colorTheme.pureColor }
    public var deepColor: Color { colorTheme.deepColor }
    public var lightColor: Color { colorTheme.lightColor }
    public var darkColor: Color { colorTheme.darkColor }
    public var mediumColor: Color { colorTheme.mediumColor }
    public var pasteltColor: Color { colorTheme.pasteltColor }
    public var burntColor: Color { colorTheme.burntColor }
    public var warmColor: Color { colorTheme.warmColor }
    public var goldenColor: Color { colorTheme.goldenColor }
    public var deepBurntColor: Color { colorTheme.deepBurntColor }
}

// MARK: - Theme Factory Helpers

/// Generic theme factory helpers
public struct ThemeFactory {
    /// Creates a configuration with default settings
    public static func configuration<T: ColorTheme>(
        for theme: T,
        variant: ThemeVariant = .vibrant
    ) -> ThemeConfiguration<T> {
        ThemeConfiguration(colorTheme: theme, variant: variant)
    }

    /// Creates a configuration with custom animation settings
    public static func configuration<T: ColorTheme>(
        for theme: T,
        variant: ThemeVariant = .vibrant,
        animationDuration: Double,
        hueRotationIntensity: Double = 20.0
    ) -> ThemeConfiguration<T> {
        ThemeConfiguration(
            colorTheme: theme,
            variant: variant,
            animationDuration: animationDuration,
            hueRotationIntensity: hueRotationIntensity
        )
    }

    // MARK: - Dynamic Theme Convenience Methods

    /// Creates a dynamic theme from a base color
    public static func dynamic(
        baseColor: Color,
        variant: ThemeVariant = .vibrant
    ) -> ThemeConfiguration<DynamicTheme> {
        ThemeConfiguration(colorTheme: DynamicTheme(baseColor: baseColor), variant: variant)
    }

    /// Creates a dynamic theme with custom settings
    public static func dynamic(
        baseColor: Color,
        variant: ThemeVariant = .vibrant,
        animationDuration: Double = 8.0,
        hueRotationIntensity: Double = 20.0
    ) -> ThemeConfiguration<DynamicTheme> {
        ThemeConfiguration(
            colorTheme: DynamicTheme(baseColor: baseColor),
            variant: variant,
            animationDuration: animationDuration,
            hueRotationIntensity: hueRotationIntensity
        )
    }

    // MARK: - Predefined Dynamic Themes

    /// Orange dynamic theme
    public static func orange(variant: ThemeVariant = .vibrant) -> ThemeConfiguration<DynamicTheme>
    {
        dynamic(baseColor: Color(red: 1.0, green: 0.5, blue: 0.0), variant: variant)
    }

    /// Blue dynamic theme
    public static func blue(variant: ThemeVariant = .vibrant) -> ThemeConfiguration<DynamicTheme> {
        dynamic(baseColor: Color(red: 0.0, green: 0.5, blue: 1.0), variant: variant)
    }

    /// Green dynamic theme
    public static func green(variant: ThemeVariant = .vibrant) -> ThemeConfiguration<DynamicTheme> {
        dynamic(baseColor: Color(red: 0.0, green: 0.8, blue: 0.2), variant: variant)
    }

    /// Red dynamic theme
    public static func red(variant: ThemeVariant = .vibrant) -> ThemeConfiguration<DynamicTheme> {
        dynamic(baseColor: Color(red: 1.0, green: 0.0, blue: 0.0), variant: variant)
    }

    /// Purple dynamic theme
    public static func purple(variant: ThemeVariant = .vibrant) -> ThemeConfiguration<DynamicTheme>
    {
        dynamic(baseColor: Color(red: 0.6, green: 0.0, blue: 0.8), variant: variant)
    }

    /// Pink dynamic theme
    public static func pink(variant: ThemeVariant = .vibrant) -> ThemeConfiguration<DynamicTheme> {
        dynamic(baseColor: Color(red: 1.0, green: 0.2, blue: 0.6), variant: variant)
    }

    /// Yellow dynamic theme
    public static func yellow(variant: ThemeVariant = .vibrant) -> ThemeConfiguration<DynamicTheme>
    {
        dynamic(baseColor: Color(red: 1.0, green: 0.8, blue: 0.0), variant: variant)
    }

    /// Teal dynamic theme
    public static func teal(variant: ThemeVariant = .vibrant) -> ThemeConfiguration<DynamicTheme> {
        dynamic(baseColor: Color(red: 0.0, green: 0.8, blue: 0.8), variant: variant)
    }

    /// Indigo dynamic theme
    public static func indigo(variant: ThemeVariant = .vibrant) -> ThemeConfiguration<DynamicTheme>
    {
        dynamic(baseColor: Color(red: 0.3, green: 0.0, blue: 0.8), variant: variant)
    }

    /// Mint dynamic theme
    public static func mint(variant: ThemeVariant = .vibrant) -> ThemeConfiguration<DynamicTheme> {
        dynamic(baseColor: Color(red: 0.0, green: 1.0, blue: 0.8), variant: variant)
    }

    /// Cyan dynamic theme
    public static func cyan(variant: ThemeVariant = .vibrant) -> ThemeConfiguration<DynamicTheme> {
        dynamic(baseColor: Color(red: 0.0, green: 1.0, blue: 1.0), variant: variant)
    }

    /// Brown dynamic theme
    public static func brown(variant: ThemeVariant = .vibrant) -> ThemeConfiguration<DynamicTheme> {
        dynamic(baseColor: Color(red: 0.6, green: 0.4, blue: 0.2), variant: variant)
    }

    // MARK: - Custom Color Dynamic Themes

    /// Creates a custom color dynamic theme
    public static func custom(
        red: Double, green: Double, blue: Double,
        variant: ThemeVariant = .vibrant
    ) -> ThemeConfiguration<DynamicTheme> {
        dynamic(baseColor: Color(red: red, green: green, blue: blue), variant: variant)
    }
}
