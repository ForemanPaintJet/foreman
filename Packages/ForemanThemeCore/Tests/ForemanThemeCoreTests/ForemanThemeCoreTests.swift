//
//  ForemanThemeCoreTests.swift
//  ForemanThemeCoreTests
//
//  Created by Theme System on 2025/7/9.
//

import XCTest
import SwiftUI
@testable import ForemanThemeCore

// MARK: - Test Theme

struct TestTheme: ColorTheme {
    let brightColor = Color.red
    let pureColor = Color.red.opacity(0.8)
    let deepColor = Color.red.opacity(0.6)
    let lightColor = Color.red.opacity(0.3)
    let darkColor = Color.red.opacity(0.9)
    let mediumColor = Color.red.opacity(0.5)
    let pasteltColor = Color.red.opacity(0.2)
    let burntColor = Color.red.opacity(0.7)
    let warmColor = Color.red.opacity(0.4)
    let goldenColor = Color.yellow.opacity(0.6)
    let deepBurntColor = Color.red.opacity(0.8)
}

final class ForemanThemeCoreTests: XCTestCase {
    
    func testColorThemeProtocol() {
        let theme = TestTheme()
        
        // Test that all required properties are accessible
        XCTAssertNotNil(theme.brightColor)
        XCTAssertNotNil(theme.pureColor)
        XCTAssertNotNil(theme.primary)
        XCTAssertNotNil(theme.secondary)
        XCTAssertNotNil(theme.accent)
        XCTAssertNotNil(theme.background)
        XCTAssertNotNil(theme.meshGradientColors)
        
        // Test mesh gradient colors count
        XCTAssertEqual(theme.meshGradientColors.count, 12)
        
        // Test default mappings
        XCTAssertEqual(theme.primary, theme.pureColor)
        XCTAssertEqual(theme.secondary, theme.warmColor)
        XCTAssertEqual(theme.accent, theme.goldenColor)
        XCTAssertEqual(theme.background, theme.lightColor)
    }
    
    func testDynamicTheme() {
        let baseColor = Color(red: 0.0, green: 0.5, blue: 1.0) // Explicit RGB blue
        let dynamicTheme = DynamicTheme(baseColor: baseColor)
        
        // Test that all colors are generated
        XCTAssertNotNil(dynamicTheme.brightColor)
        XCTAssertNotNil(dynamicTheme.pureColor)
        XCTAssertNotNil(dynamicTheme.deepColor)
        XCTAssertNotNil(dynamicTheme.lightColor)
        XCTAssertNotNil(dynamicTheme.darkColor)
        XCTAssertNotNil(dynamicTheme.mediumColor)
        XCTAssertNotNil(dynamicTheme.pasteltColor)
        XCTAssertNotNil(dynamicTheme.burntColor)
        XCTAssertNotNil(dynamicTheme.warmColor)
        XCTAssertNotNil(dynamicTheme.goldenColor)
        XCTAssertNotNil(dynamicTheme.deepBurntColor)
        
        // Test that pure color matches base
        XCTAssertEqual(dynamicTheme.pureColor, baseColor)
        
        // Test mesh gradient
        XCTAssertEqual(dynamicTheme.meshGradientColors.count, 12)
        
        // Test semantic colors
        XCTAssertEqual(dynamicTheme.primary, dynamicTheme.pureColor)
        XCTAssertEqual(dynamicTheme.secondary, dynamicTheme.warmColor)
        XCTAssertEqual(dynamicTheme.accent, dynamicTheme.goldenColor)
        XCTAssertEqual(dynamicTheme.background, dynamicTheme.lightColor)
    }
    
    func testColorAdjustment() {
        let baseColor = Color(red: 1.0, green: 0.0, blue: 0.0) // Explicit RGB red
        
        // Test brightness adjustment
        let brighterColor = baseColor.adjust(brightnessMultiplier: 1.5)
        XCTAssertNotNil(brighterColor)
        
        // Test saturation adjustment
        let desaturatedColor = baseColor.adjust(saturationMultiplier: 0.5)
        XCTAssertNotNil(desaturatedColor)
        
        // Test hue adjustment
        let hueShiftedColor = baseColor.adjust(hueOffset: 0.2)
        XCTAssertNotNil(hueShiftedColor)
        
        // Test combined adjustments
        let combinedColor = baseColor.adjust(
            hueOffset: 0.1,
            saturationMultiplier: 0.8,
            brightnessMultiplier: 1.2
        )
        XCTAssertNotNil(combinedColor)
    }
    
    func testThemeConfiguration() {
        let theme = TestTheme()
        let config = ThemeConfiguration(colorTheme: theme)
        
        // Test default values
        XCTAssertEqual(config.variant, .vibrant)
        XCTAssertEqual(config.animationDuration, 8.0)
        XCTAssertEqual(config.hueRotationIntensity, 20.0)
        
        // Test convenience accessors
        XCTAssertEqual(config.primary, theme.primary)
        XCTAssertEqual(config.secondary, theme.secondary)
        XCTAssertEqual(config.accent, theme.accent)
        XCTAssertEqual(config.background, theme.background)
        
        // Test mesh colors
        XCTAssertEqual(config.meshColors.count, 12)
        
        // Test hue rotation range
        let range = config.hueRotationRange
        XCTAssertEqual(range.min, -10.0)
        XCTAssertEqual(range.max, 10.0)
    }
    
    func testThemeVariants() {
        let theme = TestTheme()
        
        // Test light variant
        let lightColors = ThemeVariant.light.meshColors(for: theme)
        XCTAssertEqual(lightColors.count, 12)
        
        // Test dark variant
        let darkColors = ThemeVariant.dark.meshColors(for: theme)
        XCTAssertEqual(darkColors.count, 12)
        
        // Test vibrant variant
        let vibrantColors = ThemeVariant.vibrant.meshColors(for: theme)
        XCTAssertEqual(vibrantColors.count, 12)
        
        // Test animation intensity
        XCTAssertEqual(ThemeVariant.light.animationIntensity, 8)
        XCTAssertEqual(ThemeVariant.dark.animationIntensity, 12)
        XCTAssertEqual(ThemeVariant.vibrant.animationIntensity, 20)
        
        // Test suggested animation duration
        XCTAssertEqual(ThemeVariant.light.suggestedAnimationDuration, 10.0)
        XCTAssertEqual(ThemeVariant.dark.suggestedAnimationDuration, 6.0)
        XCTAssertEqual(ThemeVariant.vibrant.suggestedAnimationDuration, 8.0)
    }
    
    func testThemeFactory() {
        let theme = TestTheme()
        
        // Test basic factory method
        let config1 = ThemeFactory.configuration(for: theme)
        XCTAssertEqual(config1.variant, .vibrant)
        XCTAssertEqual(config1.animationDuration, 8.0)
        
        // Test variant factory method
        let config2 = ThemeFactory.configuration(for: theme, variant: .light)
        XCTAssertEqual(config2.variant, .light)
        
        // Test custom animation factory method
        let config3 = ThemeFactory.configuration(
            for: theme,
            variant: .dark,
            animationDuration: 12.0,
            hueRotationIntensity: 30.0
        )
        XCTAssertEqual(config3.variant, .dark)
        XCTAssertEqual(config3.animationDuration, 12.0)
        XCTAssertEqual(config3.hueRotationIntensity, 30.0)
    }
    
    func testDynamicThemeFactory() {
        // Test basic dynamic theme creation
        let orangeTheme = ThemeFactory.orange()
        XCTAssertTrue(orangeTheme.colorTheme is DynamicTheme)
        XCTAssertEqual(orangeTheme.variant, .vibrant)
        
        // Test dynamic theme with variant
        let blueTheme = ThemeFactory.blue(variant: .dark)
        XCTAssertTrue(blueTheme.colorTheme is DynamicTheme)
        XCTAssertEqual(blueTheme.variant, .dark)
        
        // Test custom color dynamic theme
        let customTheme = ThemeFactory.custom(red: 0.8, green: 0.2, blue: 0.4)
        XCTAssertTrue(customTheme.colorTheme is DynamicTheme)
        
        // Test direct dynamic theme creation
        let directTheme = ThemeFactory.dynamic(baseColor: Color.purple)
        XCTAssertTrue(directTheme.colorTheme is DynamicTheme)
        XCTAssertEqual(directTheme.colorTheme.pureColor, Color.purple)
    }
    
    func testPredefinedDynamicThemes() {
        let themes = [
            ThemeFactory.orange(),
            ThemeFactory.blue(),
            ThemeFactory.green(),
            ThemeFactory.red(),
            ThemeFactory.purple(),
            ThemeFactory.pink(),
            ThemeFactory.yellow(),
            ThemeFactory.teal(),
            ThemeFactory.indigo(),
            ThemeFactory.mint(),
            ThemeFactory.cyan(),
            ThemeFactory.brown()
        ]
        
        for theme in themes {
            XCTAssertTrue(theme.colorTheme is DynamicTheme)
            XCTAssertEqual(theme.variant, .vibrant)
            XCTAssertEqual(theme.meshColors.count, 12)
        }
    }
    
    func testThemeVariantCases() {
        let allCases = ThemeVariant.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.light))
        XCTAssertTrue(allCases.contains(.dark))
        XCTAssertTrue(allCases.contains(.vibrant))
    }
}
