import Foundation

/// Protocol for app-specific settings that can be stored in PROJECT.md frontmatter.
///
/// Apps conform to this protocol to define their own settings structure.
/// Settings are stored under a unique section key in the YAML frontmatter,
/// allowing multiple applications to extend PROJECT.md without conflicts.
///
/// ## Overview
///
/// The `AppFrontMatterSettings` protocol enables a plugin architecture where
/// each app can define its own custom settings that are:
/// - Stored in PROJECT.md alongside standard project metadata
/// - Namespaced by a unique section key to prevent conflicts
/// - Fully typed for compile-time safety
/// - Automatically serialized to/from YAML
///
/// ## Usage
///
/// Define a struct conforming to this protocol with your app's settings:
///
/// ```swift
/// struct MyAppSettings: AppFrontMatterSettings {
///     static let sectionKey = "myapp"
///
///     var theme: String?
///     var autoSave: Bool?
///     var exportFormat: String?
/// }
/// ```
///
/// Then use the `ProjectFrontMatter` extension methods to read and write settings:
///
/// ```swift
/// // Read settings
/// if let settings = try frontMatter.settings(for: MyAppSettings.self) {
///     print("Theme: \(settings.theme ?? "default")")
/// }
///
/// // Write settings
/// let newSettings = MyAppSettings(theme: "dark", autoSave: true)
/// try frontMatter.setSettings(newSettings)
/// ```
///
/// ## Section Key Requirements
///
/// The `sectionKey` property identifies your app's settings section in the YAML frontmatter.
/// It must be:
/// - **Unique** across all apps using the same PROJECT.md file
/// - **Stable** (never changed after first use, or data will be lost)
/// - **Descriptive** (prefer app name over generic keys like "settings")
///
/// ### Recommended Naming
///
/// - Use your app's name: `"myapp"`, `"podcast"`, `"screenplay"`
/// - Use bundle identifier: `"com.example.myapp"`
/// - Avoid generic names: `"config"`, `"settings"`, `"data"`
///
/// ## Best Practices
///
/// 1. **Use Optional Fields**: Make all settings properties optional to support
///    partial configuration and backward compatibility:
///    ```swift
///    var theme: String?  // ✅ Good
///    var theme: String   // ❌ Requires value always
///    ```
///
/// 2. **Provide Defaults**: Use extensions to define default values:
///    ```swift
///    extension MyAppSettings {
///        static var `default`: Self {
///            MyAppSettings(theme: "light", autoSave: true)
///        }
///    }
///    ```
///
/// 3. **Version Your Schema**: Include a version field to support migrations:
///    ```swift
///    struct MyAppSettings: AppFrontMatterSettings {
///        static let sectionKey = "myapp"
///        var schemaVersion: Int? = 1
///        var theme: String?
///    }
///    ```
///
/// 4. **Use Nested Types**: Group related settings with nested structures:
///    ```swift
///    struct MyAppSettings: AppFrontMatterSettings {
///        static let sectionKey = "myapp"
///        var ui: UISettings?
///        var export: ExportSettings?
///
///        struct UISettings: Codable, Sendable {
///            var theme: String?
///            var fontSize: Int?
///        }
///
///        struct ExportSettings: Codable, Sendable {
///            var format: String?
///            var quality: Int?
///        }
///    }
///    ```
///
/// ## YAML Structure
///
/// Settings appear at the root level of PROJECT.md frontmatter, not nested:
///
/// ```yaml
/// ---
/// type: project
/// title: My Project
/// author: John Doe
/// myapp:
///   theme: dark
///   autoSave: true
/// ---
/// ```
///
/// ## Type Safety
///
/// All settings must be `Codable` and `Sendable`:
/// - **Codable**: Enables automatic YAML serialization
/// - **Sendable**: Ensures thread-safety for Swift 6 concurrency
///
/// ## See Also
///
/// - `ProjectFrontMatter.settings(for:)`: Read typed settings
/// - `ProjectFrontMatter.setSettings(_:)`: Write typed settings
/// - `ProjectFrontMatter.hasSettings(for:)`: Check if settings exist
public protocol AppFrontMatterSettings: Codable, Sendable {
    /// Unique key for this app's settings section in YAML frontmatter.
    ///
    /// This key identifies where your app's settings are stored in the PROJECT.md
    /// frontmatter. It must be unique across all apps using the same PROJECT.md file.
    ///
    /// ## Requirements
    ///
    /// - Must be unique across all apps
    /// - Must remain stable (never change after first use)
    /// - Should be descriptive and app-specific
    ///
    /// ## Examples
    ///
    /// ```swift
    /// static let sectionKey = "myapp"              // ✅ Good
    /// static let sectionKey = "com.example.app"    // ✅ Good
    /// static let sectionKey = "settings"           // ❌ Too generic
    /// ```
    ///
    /// ## Naming Recommendations
    ///
    /// - **App Name**: Use your application name (e.g., "podcast", "screenplay")
    /// - **Bundle ID**: Use your bundle identifier (e.g., "com.example.myapp")
    /// - **Avoid Generic Names**: Don't use "config", "settings", "data", etc.
    ///
    /// ## Stability Warning
    ///
    /// Never change the `sectionKey` after your app has been released. Changing it
    /// will cause existing PROJECT.md files to lose their settings data. If you must
    /// change the key, implement a migration that reads from the old key and writes
    /// to the new key.
    static var sectionKey: String { get }
}
