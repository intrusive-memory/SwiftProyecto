//
//  BackendRegistry.swift
//  SwiftProyecto
//
//  Copyright (c) 2025 Intrusive Memory
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import Foundation

/// Registry for discovering and managing available LLM backends.
///
/// `BackendRegistry` is a singleton that maintains a collection of registered
/// LLM backends. Backends register themselves at initialization, and the registry
/// provides methods to query available backends and retrieve specific backends by name.
///
/// ## Design
///
/// - **Singleton**: Use `BackendRegistry.shared` to access the registry
/// - **Thread-safe**: Uses a lock to synchronize concurrent access
/// - **Availability-aware**: Methods return only backends where `isAvailable == true`
/// - **Name-based lookup**: Retrieve backends by their `backendName` property
///
/// ## Usage
///
/// ```swift
/// // Register a backend (typically done at app initialization)
/// let myBackend = MyCustomBackend()
/// BackendRegistry.shared.register(myBackend)
///
/// // Get all available backends
/// let backends = BackendRegistry.shared.availableBackends()
/// for backend in backends {
///   print("Available: \(backend.backendName)")
/// }
///
/// // Get a specific backend by name
/// if let backend = BackendRegistry.shared.backend(named: "Claude API") {
///   do {
///     let metadata = try await backend.generate(project: analysis)
///     // Use metadata...
///   } catch {
///     // Handle error...
///   }
/// }
/// ```
public final class BackendRegistry: @unchecked Sendable {
  /// Shared singleton instance.
  public static let shared = BackendRegistry()

  /// Stored backends (protected by lock).
  private var backends: [LLMBackendProtocol] = []
  private let lock = NSLock()

  /// Initialize the registry with no backends.
  ///
  /// Backends are registered separately via `register(_:)`.
  /// This initializer is internal for testing purposes.
  internal init() {}

  /// Register a backend with the registry.
  ///
  /// This method is thread-safe and may be called from any thread.
  /// Duplicate registrations of the same backend (by name) are allowed;
  /// both will be stored. Use `availableBackends()` or `backend(named:)`
  /// to query registered backends.
  ///
  /// - Parameter backend: The backend to register
  public func register(_ backend: LLMBackendProtocol) {
    lock.withLock {
      backends.append(backend)
    }
  }

  /// Get all available backends.
  ///
  /// Returns only backends where `isAvailable == true`.
  ///
  /// - Returns: Array of available backends, ordered by registration
  public func availableBackends() -> [LLMBackendProtocol] {
    lock.withLock {
      backends.filter { $0.isAvailable }
    }
  }

  /// Get a backend by name.
  ///
  /// Returns the first backend matching `backendName` where `isAvailable == true`.
  /// If no available backend is found, returns `nil`.
  ///
  /// - Parameter name: The backend name to search for
  /// - Returns: The backend, if found and available; otherwise `nil`
  public func backend(named name: String) -> LLMBackendProtocol? {
    lock.withLock {
      backends.first { $0.backendName == name && $0.isAvailable }
    }
  }

  /// Get all registered backends (including unavailable ones).
  ///
  /// This is primarily for testing and debugging.
  ///
  /// - Returns: All registered backends, regardless of availability
  public func allBackends() -> [LLMBackendProtocol] {
    lock.withLock {
      backends
    }
  }
}

// MARK: - NSLock Extension

extension NSLock {
  /// Execute a closure while holding the lock.
  fileprivate func withLock<T>(_ body: () -> T) -> T {
    lock()
    defer { unlock() }
    return body()
  }
}
