# TCA-Style Theme Dependency System

## Overview

The theme system has been refactored to follow The Composable Architecture (TCA) dependency injection pattern. This makes the system more testable, modular, and follows dependency injection best practices.

## Key Components

### 1. Theme Service Protocol

```swift
protocol ThemeServiceProtocol {
    func themeConfiguration(for theme: AppTheme, variant: ThemeVariant) -> ThemeConfiguration<DynamicTheme>
    func availableThemes() -> [AppTheme]
    func availableVariants() -> [ThemeVariant]
}
```

### 2. Concrete Implementation

```swift
struct ThemeService: ThemeServiceProtocol {
    // Implementation that uses ForemanThemeCore
}
```

### 3. Dependency Key

```swift
struct ThemeServiceKey: DependencyKey {
    static let liveValue: ThemeServiceProtocol = ThemeService()
    static let testValue: ThemeServiceProtocol = MockThemeService()
    static let previewValue: ThemeServiceProtocol = ThemeService()
}
```

### 4. Theme Manager with Dependency Injection

```swift
@Observable
class ThemeManager {
    @Dependency(\.themeService) var themeService
    
    // Uses injected service for all theme operations
}
```

## Usage Examples

### Basic Usage

```swift
let themeManager = ThemeManager()
let config = themeManager.themeConfiguration()

// Change theme
themeManager.setTheme(.green)
themeManager.setVariant(.dark)
```

### Testing with Mock Service

```swift
// In tests, the system automatically uses MockThemeService
let manager = ThemeManager()
// Will use mock service that returns predictable data
```

### Custom Dependency Injection

```swift
// You can override dependencies for testing
var dependencies = DependencyValues()
dependencies.themeService = MockThemeService()
```

## Benefits

1. **Testability**: Easy to test with mock implementations
2. **Modularity**: Service can be swapped out independently
3. **Dependency Injection**: Follows TCA patterns for clean architecture
4. **Type Safety**: Protocol-based approach ensures type safety
5. **Flexibility**: Easy to add new theme sources or modify behavior

## Integration

The system is designed to work with your existing `ForemanThemeCore` package while providing a clean dependency injection layer that follows TCA best practices.

To use in SwiftUI views:

```swift
struct MyView: View {
    @State private var themeManager = ThemeManager()
    
    var body: some View {
        // Use themeManager.themeConfiguration() to get current theme
        ZStack {
            MeshGradient(
                width: 3,
                height: 4,
                points: [...],
                colors: themeManager.themeConfiguration().meshColors
            )
        }
    }
}
```

The dependency system automatically handles:
- Live implementation in production
- Mock implementation in tests
- Preview implementation in SwiftUI previews
