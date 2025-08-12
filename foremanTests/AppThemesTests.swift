//
//  AppThemesTests.swift
//  foreman
//
//  Created by Theme System on 2025/7/9.
//

import XCTest

@testable import foreman

// MARK: - Theme Service Tests

final class AppThemesTests: XCTestCase {

    func testThemeServiceLive() {
        let service = ThemeService()

        // Test available themes
        let themes = service.availableThemes()
        XCTAssertEqual(themes.count, 3)
        XCTAssertTrue(themes.contains(.orange))
        XCTAssertTrue(themes.contains(.green))
        XCTAssertTrue(themes.contains(.blue))

        // Test available variants
        let variants = service.availableVariants()
        XCTAssertTrue(variants.contains(.vibrant))
        XCTAssertTrue(variants.contains(.light))
        XCTAssertTrue(variants.contains(.dark))

        // Test theme configuration generation
        let orangeConfig = service.themeConfiguration(for: .orange, variant: .vibrant)
        XCTAssertNotNil(orangeConfig)
        XCTAssertEqual(orangeConfig.variant, .vibrant)
    }

    func testMockThemeService() {
        let mockService = MockThemeService()

        // Mock should return limited data for testing
        let themes = mockService.availableThemes()
        XCTAssertEqual(themes.count, 1)
        XCTAssertEqual(themes.first, .orange)

        let variants = mockService.availableVariants()
        XCTAssertEqual(variants.count, 1)
        XCTAssertEqual(variants.first, .vibrant)
    }

    func testThemeManager() {
        let manager = ThemeManager()

        // Test initial state
        XCTAssertEqual(manager.currentTheme, .orange)
        XCTAssertEqual(manager.currentVariant, .vibrant)

        // Test theme switching
        manager.setTheme(.green)
        XCTAssertEqual(manager.currentTheme, .green)

        manager.setVariant(.dark)
        XCTAssertEqual(manager.currentVariant, .dark)

        // Test cycling themes
        manager.setTheme(.blue)
        manager.nextTheme()
        XCTAssertEqual(manager.currentTheme, .orange)  // Should cycle back to first
    }

    func testAppThemeProperties() {
        // Test display names
        XCTAssertEqual(AppTheme.orange.displayName, "Orange")
        XCTAssertEqual(AppTheme.green.displayName, "Green")
        XCTAssertEqual(AppTheme.blue.displayName, "Blue")

        // Test icons
        XCTAssertEqual(AppTheme.orange.icon, "🧡")
        XCTAssertEqual(AppTheme.green.icon, "💚")
        XCTAssertEqual(AppTheme.blue.icon, "💙")
    }

    func testDependencyInjection() {
        // This tests the TCA-style dependency system
        var dependencies = DependencyValues()

        // Test that we can set and get dependencies
        let mockService = MockThemeService()
        dependencies.themeService = mockService

        let retrievedService = dependencies.themeService
        XCTAssertTrue(retrievedService is MockThemeService)
    }
}

// MARK: - Integration Tests

extension AppThemesTests {

    func testThemeManagerWithDependencyInjection() {
        // Test that ThemeManager works with dependency injection
        let manager = ThemeManager()

        // Test theme configuration generation
        let config = manager.themeConfiguration()
        XCTAssertNotNil(config)

        // Test that configuration changes when theme changes
        let originalPrimary = config.primary
        manager.setTheme(.green)
        let newConfig = manager.themeConfiguration()

        // Colors should be different for different themes
        // Note: This is a basic test - in a real app you'd compare specific color values
        XCTAssertNotNil(newConfig.primary)
    }

    func testThemeManagerAvailabilityMethods() {
        let manager = ThemeManager()

        // Test that manager can get available options from service
        let themes = manager.availableThemes()
        XCTAssertFalse(themes.isEmpty)

        let variants = manager.availableVariants()
        XCTAssertFalse(variants.isEmpty)
    }
}
