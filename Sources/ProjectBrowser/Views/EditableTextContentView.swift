import SwiftUI

// MARK: - EditableTextContentView

/// The default editable view for a text file's contents, rendered with
/// SwiftUI's `TextEditor`.
///
/// `ProjectDetailPane` uses this for any handler-less file whose contents
/// loaded as text (`ProjectFileContents.text != nil`). It presents the text
/// in a monospaced `TextEditor`, tracks unsaved edits, and persists them via
/// the `onSave` closure — invoked by a Save button and the ⌘S keyboard
/// shortcut. Files whose bytes aren't valid UTF-8 never reach this view;
/// they fall back to ``PlainTextContentView``'s "No content" state.
///
/// The view owns a private editing draft in `@State`, so the host should give
/// it a stable identity per file (e.g. `.id(file.id)`) to reset the draft
/// when the selection changes.
///
/// ## Example
///
/// ```swift
/// EditableTextContentView(text: contents.text ?? "") { edited in
///   try await save(edited, to: file)
/// }
/// .id(file.id)
/// ```
public struct EditableTextContentView: View {

  /// The text last known to be persisted on disk. Edits are compared against
  /// this to derive the dirty state, and it advances to the current draft on
  /// each successful save.
  @State private var savedText: String

  /// The in-progress editing buffer bound to the `TextEditor`.
  @State private var draft: String

  /// Whether a save is currently in flight (disables the Save control and
  /// shows a spinner).
  @State private var isSaving = false

  /// A human-readable error from the most recent save attempt, or `nil`.
  @State private var saveError: String?

  /// Whether the most recent save completed successfully with no edits since
  /// (drives the transient "Saved" confirmation).
  @State private var didSave = false

  /// Persists the edited text. Throwing surfaces an inline error and leaves
  /// the dirty state intact so the user can retry.
  private let onSave: (String) async throws -> Void

  /// Creates an editable text view.
  ///
  /// - Parameters:
  ///   - text: The file's current text contents.
  ///   - onSave: Persists edited text; throwing surfaces an inline error.
  public init(
    text: String,
    onSave: @escaping (String) async throws -> Void
  ) {
    _savedText = State(initialValue: text)
    _draft = State(initialValue: text)
    self.onSave = onSave
  }

  /// Whether the draft differs from the last-saved text.
  private var isDirty: Bool { draft != savedText }

  public var body: some View {
    VStack(spacing: 0) {
      editorToolbar

      Divider()

      TextEditor(text: $draft)
        .font(.system(.body, design: .monospaced))
        .textEditorStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: draft) { _, _ in
          // Any edit clears the transient "Saved" confirmation and any prior
          // error so stale status never lingers over fresh input.
          didSave = false
          saveError = nil
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Toolbar

  @ViewBuilder
  private var editorToolbar: some View {
    HStack(spacing: 12) {
      statusLabel

      Spacer()

      // An always-present ⌘S hook: enabled only when there are unsaved edits
      // and no save is in flight, so the shortcut is a no-op otherwise.
      Button("Save") {
        Task { await save() }
      }
      .buttonStyle(.borderedProminent)
      .keyboardShortcut("s", modifiers: .command)
      .disabled(!isDirty || isSaving)
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity)
  }

  @ViewBuilder
  private var statusLabel: some View {
    if isSaving {
      HStack(spacing: 6) {
        ProgressView().controlSize(.small)
        Text("Saving…")
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    } else if let saveError {
      Label(saveError, systemImage: "exclamationmark.triangle.fill")
        .font(.caption)
        .foregroundStyle(.red)
        .lineLimit(1)
        .help(saveError)
    } else if isDirty {
      Label("Unsaved changes", systemImage: "pencil")
        .font(.caption)
        .foregroundStyle(.secondary)
    } else if didSave {
      Label("Saved", systemImage: "checkmark.circle.fill")
        .font(.caption)
        .foregroundStyle(.green)
    } else {
      Text(" ")
        .font(.caption)
    }
  }

  // MARK: - Save

  private func save() async {
    guard isDirty, !isSaving else { return }

    let pending = draft
    isSaving = true
    saveError = nil
    didSave = false

    do {
      try await onSave(pending)
      savedText = pending
      // Only flag success if the user hasn't typed past `pending` in the
      // meantime, so "Saved" never contradicts a now-dirty buffer.
      didSave = (draft == pending)
    } catch {
      saveError = error.localizedDescription
    }

    isSaving = false
  }
}

// MARK: - Previews

#Preview("EditableTextContentView", traits: .fixedLayout(width: 520, height: 360)) {
  EditableTextContentView(text: "INT. OFFICE - DAY\n\nA quiet room.") { _ in
    try await Task.sleep(nanoseconds: 300_000_000)
  }
}

#Preview("EditableTextContentView - Save Fails", traits: .fixedLayout(width: 520, height: 360)) {
  EditableTextContentView(text: "Edit me, then save.") { _ in
    throw ProjectFileActionError.permissionDenied("draft.txt")
  }
}
