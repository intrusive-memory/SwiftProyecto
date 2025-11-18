# Contributing to SwiftProyecto

Thank you for your interest in contributing to SwiftProyecto! This document provides guidelines and information for contributors.

## Development Process

SwiftProyecto is developed in **7 phases** as outlined in [IMPLEMENTATION_STRATEGY.md](./Docs/IMPLEMENTATION_STRATEGY.md). Each phase is independently testable and builds on the previous phase.

### Current Status

🚧 **Phase 0: Foundation** (In Progress)

See the [Implementation Strategy](./Docs/IMPLEMENTATION_STRATEGY.md) for the complete roadmap.

## Getting Started

### Prerequisites

- Swift 6.2+
- Xcode 16.0+
- macOS 26.0+ or iOS 26.0+

### Clone and Build

```bash
git clone https://github.com/intrusive-memory/SwiftProyecto.git
cd SwiftProyecto
swift build
```

### Run Tests

```bash
swift test
```

## Code Standards

### Swift Style Guide

- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Document public APIs with DocC-style comments
- Prefer value types over reference types where appropriate
- Use `@MainActor` isolation for SwiftData operations

### Testing Requirements

- **Test Coverage Target**: 80%+ for all new code
- Write unit tests for all public APIs
- Write integration tests for complex workflows
- All tests must pass before merging

### Documentation

- Document all public types, methods, and properties
- Include usage examples in documentation
- Update README.md for new features
- Update CHANGELOG.md for all changes

## Pull Request Process

1. **Create a Feature Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make Changes**
   - Write code following style guide
   - Add tests for new functionality
   - Update documentation

3. **Run Tests**
   ```bash
   swift test
   ```

4. **Commit Changes**
   - Use clear, descriptive commit messages
   - Reference issue numbers if applicable

   ```bash
   git commit -m "Add ProjectModel SwiftData model (#123)"
   ```

5. **Push and Create PR**
   ```bash
   git push origin feature/your-feature-name
   ```
   - Create pull request on GitHub
   - Fill out PR template
   - Link related issues

6. **Code Review**
   - Address feedback from maintainers
   - Make requested changes
   - Push updates to same branch

7. **Merge**
   - Maintainer will merge when approved
   - Delete feature branch after merge

## Reporting Issues

### Bug Reports

When reporting bugs, please include:

- Swift version
- Platform (iOS/macOS) and version
- Minimal reproduction steps
- Expected vs actual behavior
- Relevant error messages or logs

### Feature Requests

When requesting features:

- Describe the use case
- Explain why existing functionality doesn't solve the problem
- Suggest implementation approach (optional)

## Development Workflow

### Phase-Based Development

SwiftProyecto is developed in phases. Contributing to the current phase:

1. Check [IMPLEMENTATION_STRATEGY.md](./Docs/IMPLEMENTATION_STRATEGY.md) for current phase
2. Review phase deliverables and success criteria
3. Claim a deliverable by commenting on related issue
4. Implement, test, and submit PR

### Working on Future Phases

To work on future phases:

1. Wait for current phase completion
2. OR discuss with maintainers if you want to work ahead
3. Ensure dependencies from previous phases are complete

## Code of Conduct

### Be Respectful

- Be kind and courteous to other contributors
- Welcome newcomers and help them get started
- Provide constructive feedback

### Focus on the Code

- Critique code, not people
- Assume good intent
- Discuss technical merits

## Questions?

- Open an issue for questions
- Tag with `question` label
- Maintainers will respond

## License

By contributing to SwiftProyecto, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to SwiftProyecto! 🎬
