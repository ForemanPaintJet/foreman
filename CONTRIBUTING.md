# Contributing to Foreman

Thank you for your interest in contributing to Foreman! This document provides guidelines and information for contributors.

## Getting Started

1. Fork the repository on Bitbucket
2. Clone your fork locally:
   ```bash
   git clone https://bitbucket.org/[your-username]/foreman.git
   cd foreman
   ```
3. Open the project in Xcode and ensure it builds successfully

## Development Workflow

### Branching Strategy

- `main` - Stable release branch
- `develop` - Main development branch
- `feature/[feature-name]` - Feature development branches
- `bugfix/[bug-description]` - Bug fix branches
- `hotfix/[hotfix-description]` - Critical hotfix branches

### Making Changes

1. Create a new branch from `develop`:
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/your-feature-name
   ```

2. Make your changes following the coding standards below

3. Test your changes thoroughly:
   - Run unit tests
   - Run UI tests
   - Test on different device sizes and iOS versions

4. Commit your changes with clear, descriptive messages:
   ```bash
   git add .
   git commit -m "Add feature: clear description of what was added"
   ```

5. Push to your fork and create a pull request

## Coding Standards

### Swift Style Guide

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use 4 spaces for indentation (no tabs)
- Maximum line length of 120 characters
- Use meaningful variable and function names
- Add documentation comments for public APIs

### SwiftUI Best Practices

- Prefer composition over inheritance
- Keep views small and focused
- Use `@State`, `@Binding`, and `@ObservableObject` appropriately
- Follow MVVM pattern where applicable

### Code Organization

- Group related functionality into separate files
- Use meaningful folder structure
- Keep view files focused on UI logic
- Separate business logic into dedicated classes/structs

## Testing

### Unit Tests

- Write unit tests for business logic
- Aim for high test coverage (>80%)
- Use descriptive test names that explain what is being tested
- Follow Arrange-Act-Assert pattern

### UI Tests

- Write UI tests for critical user flows
- Test on multiple device sizes
- Use accessibility identifiers for UI elements

## Pull Request Process

1. Ensure your branch is up to date with `develop`
2. Make sure all tests pass
3. Update documentation if needed
4. Fill out the pull request template completely
5. Request review from maintainers

### Pull Request Guidelines

- Provide a clear description of the changes
- Reference any related issues
- Include screenshots for UI changes
- Keep pull requests focused and atomic
- Be responsive to review feedback

## Reporting Issues

When reporting issues, please include:

- iOS version
- Device model
- Steps to reproduce
- Expected vs actual behavior
- Screenshots or screen recordings if applicable
- Crash logs if relevant

## Code Review

All submissions require code review. We use Bitbucket's pull request system for this purpose.

### Review Criteria

- Code quality and maintainability
- Adherence to coding standards
- Test coverage
- Performance implications
- Security considerations
- User experience impact

## Community Guidelines

- Be respectful and constructive in discussions
- Help others learn and grow
- Focus on the code, not the person
- Be open to feedback and different perspectives

## Questions?

If you have questions about contributing, feel free to:

- Open an issue for discussion
- Reach out to the maintainers
- Check existing documentation and issues

Thank you for contributing to Foreman!
