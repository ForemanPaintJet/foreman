//
//  AppThemes.swift
//  foreman
//
//  Created by Theme System on 2025/7/9.
//

import SwiftUI
import ForemanThemeCore
import ComposableArchitecture

// MARK: - Theme Dependency

/// Theme service protocol following TCA dependency pattern
protocol ThemeServiceProtocol {
    func themeConfiguration(for theme: AppTheme, variant: ThemeVariant) -> ThemeConfiguration<DynamicTheme>
    func availableThemes() -> [AppTheme]
    func availableVariants() -> [ThemeVariant]
}

/// Concrete implementation of the theme service
struct ThemeService: ThemeServiceProtocol {
    func themeConfiguration(for theme: AppTheme, variant: ThemeVariant) -> ThemeConfiguration<DynamicTheme> {
        switch theme {
        case .orange:
            return ThemeFactory.orange(variant: variant)
        case .green:
            return ThemeFactory.green(variant: variant)
        case .blue:
            return ThemeFactory.blue(variant: variant)
        }
    }
    
    func availableThemes() -> [AppTheme] {
        AppTheme.allCases
    }
    
    func availableVariants() -> [ThemeVariant] {
        ThemeVariant.allCases
    }
}

// MARK: - Theme Dependency Key

/// Dependency key for theme service following TCA pattern
struct ThemeServiceKey: DependencyKey {
    static let liveValue: ThemeServiceProtocol = ThemeService()
    static let testValue: ThemeServiceProtocol = MockThemeService()
    static let previewValue: ThemeServiceProtocol = ThemeService()
}

extension DependencyValues {
    var themeService: ThemeServiceProtocol {
        get { self[ThemeServiceKey.self] }
        set { self[ThemeServiceKey.self] = newValue }
    }
}

// MARK: - Mock Theme Service for Testing

/// Mock implementation for testing
struct MockThemeService: ThemeServiceProtocol {
    func themeConfiguration(for theme: AppTheme, variant: ThemeVariant) -> ThemeConfiguration<DynamicTheme> {
        // Return a simple mock theme for testing
        ThemeFactory.orange(variant: .vibrant)
    }
    
    func availableThemes() -> [AppTheme] {
        [.orange]
    }
    
    func availableVariants() -> [ThemeVariant] {
        [.vibrant]
    }
}

// MARK: - App Theme Types

/// Available app themes
enum AppTheme: String, CaseIterable, Hashable {
    case orange = "Orange"
    case green = "Green"
    case blue = "Blue"
    
    /// The display name for the theme
    var displayName: String {
        return rawValue
    }
    
    /// Icon representation for the theme
    var icon: String {
        switch self {
        case .orange: return "🧡"
        case .green: return "💚"
        case .blue: return "💙"
        }
    }
}
