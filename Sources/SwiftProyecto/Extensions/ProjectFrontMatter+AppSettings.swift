import Foundation

public extension ProjectFrontMatter {

    /// Retrieve app-specific settings for a given type.
    ///
    /// - Parameter type: The settings type conforming to AppFrontMatterSettings
    /// - Returns: The settings instance if found, nil if section doesn't exist
    /// - Throws: DecodingError if settings exist but cannot be decoded to type T
    ///
    /// ## Example
    /// ```swift
    /// if let settings = try frontMatter.settings(for: MyAppSettings.self) {
    ///     print("Theme: \(settings.theme ?? "default")")
    /// }
    /// ```
    func settings<T: AppFrontMatterSettings>(for type: T.Type) throws -> T? {
        guard let anyCodable = appSections[T.sectionKey] else {
            return nil
        }

        // Decode AnyCodable back to T
        // Use JSONEncoder/Decoder for type safety
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    /// Store app-specific settings.
    ///
    /// - Parameter settings: The settings instance to store
    /// - Throws: EncodingError if settings cannot be encoded
    ///
    /// Overwrites any existing settings for the same section key.
    ///
    /// ## Example
    /// ```swift
    /// let settings = MyAppSettings(theme: "dark", autoSave: true)
    /// try frontMatter.setSettings(settings)
    /// ```
    mutating func setSettings<T: AppFrontMatterSettings>(_ settings: T) throws {
        // Encode T to AnyCodable
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        let decoder = JSONDecoder()
        let anyCodable = try decoder.decode(AnyCodable.self, from: data)

        appSections[T.sectionKey] = anyCodable
    }

    /// Check if settings exist for a given type.
    ///
    /// - Parameter type: The settings type to check for
    /// - Returns: true if settings section exists, false otherwise
    ///
    /// ## Example
    /// ```swift
    /// if frontMatter.hasSettings(for: MyAppSettings.self) {
    ///     print("Settings found")
    /// }
    /// ```
    func hasSettings<T: AppFrontMatterSettings>(for type: T.Type) -> Bool {
        return appSections[T.sectionKey] != nil
    }
}
