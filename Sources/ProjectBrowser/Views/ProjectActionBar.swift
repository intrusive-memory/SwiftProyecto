import SwiftUI

/// A row of action buttons for a `ProjectWindow` — Sync, Import, Load All,
/// and Unload All — rendered as a compact macOS toolbar-style row or an
/// iOS button group, adapting to the available width.
///
/// `ProjectActionBar` never performs the actions itself; it purely forwards
/// user intent to consumer-supplied callbacks so `ProjectWindow` (WU4) can
/// own the actual sync/import/load logic (file discovery, importer sheets,
/// lazy-loading all files, and clearing the in-memory content cache).
///
/// ## Example
///
/// ```swift
/// ProjectActionBar(
///   onSync: { discoverFiles() },
///   onImport: { isImporterPresented = true },
///   onLoadAll: { loadAllContents() },
///   onUnloadAll: { clearCachedContents() },
///   isEnabled: !isDiscovering,
///   canSync: true,
///   canImport: true,
///   canLoadAll: !fileTree.isEmpty,
///   canUnloadAll: !fileContents.isEmpty
/// )
/// ```
public struct ProjectActionBar: View {

  /// Refreshes the file list from disk.
  public let onSync: () -> Void

  /// Imports one or more files from outside the project directory.
  public let onImport: () -> Void

  /// Loads the contents of every discovered file.
  public let onLoadAll: () -> Void

  /// Clears any cached file contents, freeing memory.
  public let onUnloadAll: () -> Void

  /// When `false`, every action button is disabled regardless of the
  /// per-action `can...` flags below. Intended for use while a discovery
  /// pass or bulk load is already in flight.
  public let isEnabled: Bool

  /// Whether the Sync action is currently available.
  public let canSync: Bool

  /// Whether the Import action is currently available.
  public let canImport: Bool

  /// Whether the Load All action is currently available (for example,
  /// `false` when the file tree is empty or everything is already loaded).
  public let canLoadAll: Bool

  /// Whether the Unload All action is currently available (for example,
  /// `false` when nothing is currently loaded into memory).
  public let canUnloadAll: Bool

  #if os(iOS)
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  #endif

  public init(
    onSync: @escaping () -> Void,
    onImport: @escaping () -> Void,
    onLoadAll: @escaping () -> Void,
    onUnloadAll: @escaping () -> Void,
    isEnabled: Bool = true,
    canSync: Bool = true,
    canImport: Bool = true,
    canLoadAll: Bool = true,
    canUnloadAll: Bool = true
  ) {
    self.onSync = onSync
    self.onImport = onImport
    self.onLoadAll = onLoadAll
    self.onUnloadAll = onUnloadAll
    self.isEnabled = isEnabled
    self.canSync = canSync
    self.canImport = canImport
    self.canLoadAll = canLoadAll
    self.canUnloadAll = canUnloadAll
  }

  public var body: some View {
    #if os(macOS)
    macLayout
    #else
    iOSLayout
    #endif
  }

  // MARK: - macOS layout

  #if os(macOS)
  /// A single toolbar-style row of icon+label buttons, matching macOS
  /// window-toolbar conventions.
  private var macLayout: some View {
    HStack(spacing: 8) {
      actionButton(
        title: "Sync", systemImage: "arrow.circlepath", enabled: canSync, action: onSync)
      actionButton(
        title: "Import", systemImage: "square.and.arrow.down", enabled: canImport,
        action: onImport)

      Divider()
        .frame(height: 16)

      actionButton(
        title: "Load All", systemImage: "square.stack", enabled: canLoadAll, action: onLoadAll)
      actionButton(
        title: "Unload All", systemImage: "xmark.circle", enabled: canUnloadAll,
        action: onUnloadAll)

      Spacer()
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
  }
  #endif

  // MARK: - iOS layout

  #if !os(macOS)
  /// A two-row button group on compact-width devices (iPhone), or a single
  /// full-width row on regular-width devices (iPad).
  private var iOSLayout: some View {
    Group {
      if horizontalSizeClass == .compact {
        VStack(spacing: 8) {
          HStack(spacing: 8) {
            actionButton(
              title: "Sync", systemImage: "arrow.circlepath", enabled: canSync, action: onSync,
              expand: true)
            actionButton(
              title: "Import", systemImage: "square.and.arrow.down", enabled: canImport,
              action: onImport, expand: true)
          }
          HStack(spacing: 8) {
            actionButton(
              title: "Load All", systemImage: "square.stack", enabled: canLoadAll,
              action: onLoadAll, expand: true)
            actionButton(
              title: "Unload All", systemImage: "xmark.circle", enabled: canUnloadAll,
              action: onUnloadAll, expand: true)
          }
        }
      } else {
        HStack(spacing: 8) {
          actionButton(
            title: "Sync", systemImage: "arrow.circlepath", enabled: canSync, action: onSync,
            expand: true)
          actionButton(
            title: "Import", systemImage: "square.and.arrow.down", enabled: canImport,
            action: onImport, expand: true)
          actionButton(
            title: "Load All", systemImage: "square.stack", enabled: canLoadAll,
            action: onLoadAll, expand: true)
          actionButton(
            title: "Unload All", systemImage: "xmark.circle", enabled: canUnloadAll,
            action: onUnloadAll, expand: true)
        }
      }
    }
    .padding(8)
    .buttonStyle(.bordered)
  }
  #endif

  // MARK: - Shared button builder

  @ViewBuilder
  private func actionButton(
    title: String,
    systemImage: String,
    enabled: Bool,
    action: @escaping () -> Void,
    expand: Bool = false
  ) -> some View {
    Button(action: action) {
      Label(title, systemImage: systemImage)
        .frame(maxWidth: expand ? .infinity : nil)
    }
    .disabled(!isEnabled || !enabled)
  }
}

// MARK: - Previews

#Preview("macOS - Enabled") {
  ProjectActionBar(
    onSync: {},
    onImport: {},
    onLoadAll: {},
    onUnloadAll: {}
  )
  .frame(width: 420)
}

#Preview("macOS - Syncing (disabled)") {
  ProjectActionBar(
    onSync: {},
    onImport: {},
    onLoadAll: {},
    onUnloadAll: {},
    isEnabled: false
  )
  .frame(width: 420)
}

#Preview("iOS - Compact") {
  ProjectActionBar(
    onSync: {},
    onImport: {},
    onLoadAll: {},
    onUnloadAll: {},
    canLoadAll: true,
    canUnloadAll: false
  )
  .frame(width: 320)
}

#Preview("iOS - Regular") {
  ProjectActionBar(
    onSync: {},
    onImport: {},
    onLoadAll: {},
    onUnloadAll: {}
  )
  .frame(width: 700)
}
