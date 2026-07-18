//
//  ProjectView.swift (LEGACY - Reference Only)
//  Produciesta
//
//  Created on 2025-11-17.
//  Removed from Produciesta in commit 91353c5 (May 2026)
//
//  This file is preserved as reference for implementing a reusable
//  ProjectWindow UI component. It demonstrates:
//  - Master-detail navigation for hierarchical file browsing
//  - Lazy file loading with progress tracking
//  - File state management (not loaded, loading, loaded, stale, missing)
//  - Context menu actions per file
//  - PROJECT.md manifest viewing and editing
//

import SwiftUI
import SwiftData
import SwiftCompartido
import SwiftProyecto
import UniformTypeIdentifiers

/// View for managing and viewing screenplay projects with lazy file loading.
///
/// ProjectView provides a project-based workflow where multiple screenplay files
/// are organized in a folder structure. Files are discovered but not loaded until
/// explicitly requested by the user (lazy loading).
///
/// ## Features
/// - Project folder management
/// - File discovery and synchronization
/// - Lazy file loading (load on demand)
/// - File state indicators (not loaded, loading, loaded, stale, missing)
/// - Load/Reload actions per file
///
@MainActor
/// Selection type in the file list
enum ProjectSelection: Hashable {
    case projectManifest  // PROJECT.md
    case file(ProjectFileReference)
}

struct ProjectView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var project: ProjectModel

    @State private var selection: ProjectSelection?
    @State private var loadingFiles: Set<PersistentIdentifier> = []
    @State private var parsingProgress: [PersistentIdentifier: ParsingProgress] = [:]
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingImportPicker = false

    // Title editing
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @FocusState private var isTitleFieldFocused: Bool

    // PROJECT.md content
    @State private var projectMarkdownContent: String = ""

    // Generation progress states per loaded document
    @State private var documentProgressStates: [PersistentIdentifier: ElementProgressState] = [:]

    private var projectService: ProjectService {
        ProjectService(modelContext: modelContext)
    }

    var body: some View {
        NavigationSplitView {
            projectSidebar
        } detail: {
            detailView
        }
        .navigationTitle(project.title)
        .alert("Error", isPresented: $showingError, presenting: errorMessage) { _ in
            Button("OK") { errorMessage = nil }
        } message: { message in
            Text(message)
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: supportedFileTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }
    }

    // MARK: - Sidebar

    private var projectSidebar: some View {
        VStack(spacing: 0) {
            // Project info header
            VStack(alignment: .leading, spacing: 4) {
                // Title (editable on double-click)
                if isEditingTitle {
                    TextField("Project Title", text: $editedTitle)
                        .font(.headline)
                        .textFieldStyle(.plain)
                        .focused($isTitleFieldFocused)
                        .onSubmit {
                            saveProjectTitle()
                        }
                        #if os(macOS)
                        .onExitCommand {
                            cancelTitleEditing()
                        }
                        #endif
                } else {
                    Text(project.title)
                        .font(.headline)
                        .onTapGesture(count: 2) {
                            handleProjectTitleDoubleClick()
                        }
                }

                if let description = project.projectDescription {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Label("\(project.totalFileCount) files", systemImage: "doc.text")
                    Label("\(project.loadedFileCount) loaded", systemImage: "checkmark.circle")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                #if os(macOS)
                Color(nsColor: .controlBackgroundColor)
                #else
                Color(uiColor: .secondarySystemGroupedBackground)
                #endif
            }

            Divider()

            // File list
            if project.fileReferences.isEmpty {
                emptyStateView
            } else {
                fileList
            }

            Divider()

            // Action buttons
            actionButtons
        }
        .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Files Found")
                .font(.headline)

            Text("Add screenplay files to the project folder and click Sync")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fileList: some View {
        List(selection: $selection) {
            // Project Information Section
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)

                    Text("PROJECT.md")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("Read Only")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
                .tag(ProjectSelection.projectManifest)
            } header: {
                Text("Project Information")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Screenplay Files Section
            Section {
                ForEach(project.sortedFileReferences) { fileRef in
                    ProjectFileRow(
                        fileReference: fileRef,
                        isLoading: loadingFiles.contains(fileRef.persistentModelID),
                        onLoad: { loadFile(fileRef) },
                        onReload: { reloadFile(fileRef) },
                        onReimport: { reimportFile(fileRef) },
                        onUnload: { unloadFile(fileRef) },
                        onShowInFinder: { showInFinder(fileRef) }
                    )
                    .tag(ProjectSelection.file(fileRef))
                }
            } header: {
                Text("Screenplay Files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            loadProjectMarkdown()
        }
        .onChange(of: selection) { oldValue, newValue in
            // Reload PROJECT.md content when it's selected
            if case .projectManifest = newValue {
                loadProjectMarkdown()
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button(action: syncProject) {
                Label("Sync", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderless)

            Button(action: { showingImportPicker = true }) {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderless)

            Spacer()

            Button(action: loadAllFiles) {
                Label("Load All", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.borderless)
            .disabled(project.allFilesLoaded)
        }
        .padding()
    }

    // MARK: - Detail View

    private var detailView: some View {
        Group {
            switch selection {
            case .projectManifest:
                // Show PROJECT.md content as plain text
                projectManifestView

            case .file(let fileRef):
                // Show screenplay file
                if let loadedDocument = fileRef.loadedDocument {
                    NavigationStack {
                        GuionDocumentView(
                            document: loadedDocument,
                            isParsing: loadingFiles.contains(fileRef.persistentModelID),
                            generationProgressState: progressState(for: loadedDocument)
                        )
                        .id(loadedDocument.persistentModelID)
                    }
                } else {
                    // File selected but not loaded
                    fileNotLoadedView(for: fileRef)
                }

            case .none:
                // No selection
                Text("Select a file to view")
                    .foregroundStyle(.secondary)
                    .font(.title2)
            }
        }
    }

    private var projectManifestView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
                Text("PROJECT.md")
                    .font(.headline)
                Spacer()
                Text("Read Only")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background {
                #if os(macOS)
                Color(nsColor: .controlBackgroundColor)
                #else
                Color(uiColor: .secondarySystemGroupedBackground)
                #endif
            }

            Divider()

            // Content
            ScrollView {
                Text(projectMarkdownContent)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
    }

    // MARK: - Progress State Management

    /// Get generation progress state for a document
    private func progressState(for document: GuionDocumentModel) -> ElementProgressState {
        let docId = document.persistentModelID

        // Return existing state or create new one
        if let existing = documentProgressStates[docId] {
            return existing
        } else {
            let newState = ElementProgressState()
            documentProgressStates[docId] = newState
            return newState
        }
    }

    private func fileNotLoadedView(for fileRef: ProjectFileReference) -> some View {
        VStack(spacing: 16) {
            Image(systemName: fileRef.loadingState.systemIconName)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(fileRef.filename)
                .font(.headline)

            Text(fileRef.loadingState.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Show parsing progress if loading
            if let progress = parsingProgress[fileRef.persistentModelID] {
                VStack(spacing: 8) {
                    ProgressView(value: progress.fractionCompleted)
                        .frame(width: 200)

                    Text(progress.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else if fileRef.canLoad {
                Button(action: { loadFile(fileRef) }) {
                    Label("Load File", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func handleProjectTitleDoubleClick() {
        // Start editing title
        editedTitle = project.title
        isEditingTitle = true
        isTitleFieldFocused = true
    }

    private func saveProjectTitle() {
        guard !editedTitle.trimmingCharacters(in: .whitespaces).isEmpty else {
            cancelTitleEditing()
            return
        }

        // Update project title in SwiftData
        project.title = editedTitle
        try? modelContext.save()

        // Update PROJECT.md file
        Task {
            await updateProjectMarkdown()
        }

        isEditingTitle = false
    }

    private func cancelTitleEditing() {
        isEditingTitle = false
        editedTitle = ""
    }

    private func updateProjectMarkdown() async {
        do {
            // Resolve project folder URL from bookmark
            guard let folderBookmark = project.sourceBookmarkData else {
                showError("Project folder bookmark not found")
                return
            }

            var isStale = false
            let bookmarkResolutionOptions: URL.BookmarkResolutionOptions = {
                #if os(macOS)
                return .withSecurityScope
                #else
                return []
                #endif
            }()
            let projectURL = try URL(
                resolvingBookmarkData: folderBookmark,
                options: bookmarkResolutionOptions,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            let didStartAccessing = projectURL.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    projectURL.stopAccessingSecurityScopedResource()
                }
            }

            // Read current PROJECT.md
            let manifestURL = projectURL.appendingPathComponent("PROJECT.md")
            guard FileManager.default.fileExists(atPath: manifestURL.path) else {
                showError("PROJECT.md not found")
                return
            }

            // Parse current PROJECT.md
            let parser = ProjectMarkdownParser()
            let (frontMatter, body) = try parser.parse(fileURL: manifestURL)

            // Create updated front matter with new title
            let updatedFrontMatter = ProjectFrontMatter(
                type: frontMatter.type,
                title: project.title,  // Updated title
                author: frontMatter.author,
                created: frontMatter.created,
                description: frontMatter.description,
                season: frontMatter.season,
                episodes: frontMatter.episodes,
                genre: frontMatter.genre,
                tags: frontMatter.tags
            )

            // Generate new PROJECT.md content
            let markdownContent = parser.generate(frontMatter: updatedFrontMatter, body: body)

            // Write back to disk
            try markdownContent.write(to: manifestURL, atomically: true, encoding: String.Encoding.utf8)

        } catch {
            showError("Failed to update PROJECT.md: \(error.localizedDescription)")
        }
    }

    private func syncProject() {
        Task {
            do {
                try projectService.syncProject(project)
            } catch {
                errorMessage = "Failed to sync project: \(error.localizedDescription)"
                showingError = true
            }
        }
    }

    private func loadFile(_ fileRef: ProjectFileReference) {
        guard fileRef.canLoad else { return }

        let fileRefID = fileRef.persistentModelID
        loadingFiles.insert(fileRefID)

        Task {
            do {
                // Create progress callback
                let progress = OperationProgress(totalUnits: nil) { update in
                    Task { @MainActor in
                        self.parsingProgress[fileRefID] = ParsingProgress(
                            fractionCompleted: update.fractionCompleted ?? 0,
                            description: update.description
                        )
                    }
                }

                try await projectService.loadFile(fileRef, in: project, progress: progress)
                loadingFiles.remove(fileRefID)
                parsingProgress.removeValue(forKey: fileRefID)

                // Initialize progress state for newly loaded document
                if let loadedDocument = fileRef.loadedDocument {
                    let docId = loadedDocument.persistentModelID
                    if documentProgressStates[docId] == nil {
                        documentProgressStates[docId] = ElementProgressState()
                    }
                }

                // Select the newly loaded file
                selection = .file(fileRef)
            } catch {
                loadingFiles.remove(fileRefID)
                parsingProgress.removeValue(forKey: fileRefID)
                errorMessage = "Failed to load \(fileRef.filename): \(error.localizedDescription)"
                showingError = true
            }
        }
    }

    private func reloadFile(_ fileRef: ProjectFileReference) {
        guard fileRef.isLoaded else { return }

        // Unload then load again
        Task {
            do {
                try projectService.unloadFile(fileRef)
                try await projectService.loadFile(fileRef, in: project)
            } catch {
                errorMessage = "Failed to reload \(fileRef.filename): \(error.localizedDescription)"
                showingError = true
            }
        }
    }

    private func reimportFile(_ fileRef: ProjectFileReference) {
        let fileRefID = fileRef.persistentModelID
        loadingFiles.insert(fileRefID)

        Task {
            do {
                // Create progress callback
                let progress = OperationProgress(totalUnits: nil) { update in
                    Task { @MainActor in
                        self.parsingProgress[fileRefID] = ParsingProgress(
                            fractionCompleted: update.fractionCompleted ?? 0,
                            description: update.description
                        )
                    }
                }

                try await projectService.reimportFile(fileRef, in: project, progress: progress)
                loadingFiles.remove(fileRefID)
                parsingProgress.removeValue(forKey: fileRefID)
            } catch {
                loadingFiles.remove(fileRefID)
                parsingProgress.removeValue(forKey: fileRefID)
                errorMessage = "Failed to re-import \(fileRef.filename): \(error.localizedDescription)"
                showingError = true
            }
        }
    }

    private func unloadFile(_ fileRef: ProjectFileReference) {
        guard fileRef.isLoaded else { return }

        Task {
            do {
                try projectService.unloadFile(fileRef)
                // Clear selection if this was the selected file
                if case .file(let selectedRef) = selection,
                   selectedRef.persistentModelID == fileRef.persistentModelID {
                    selection = nil
                }
            } catch {
                errorMessage = "Failed to unload \(fileRef.filename): \(error.localizedDescription)"
                showingError = true
            }
        }
    }

    private func loadProjectMarkdown() {
        Task {
            do {
                // Resolve project folder URL from bookmark
                guard let folderBookmark = project.sourceBookmarkData else {
                    return
                }

                var isStale = false
                let bookmarkResolutionOptions: URL.BookmarkResolutionOptions = {
                    #if os(macOS)
                    return .withSecurityScope
                    #else
                    return []
                    #endif
                }()
                let projectURL = try URL(
                    resolvingBookmarkData: folderBookmark,
                    options: bookmarkResolutionOptions,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                let didStartAccessing = projectURL.startAccessingSecurityScopedResource()
                defer {
                    if didStartAccessing {
                        projectURL.stopAccessingSecurityScopedResource()
                    }
                }

                // Read PROJECT.md content
                let manifestURL = projectURL.appendingPathComponent("PROJECT.md")
                guard FileManager.default.fileExists(atPath: manifestURL.path()) else {
                    await MainActor.run {
                        projectMarkdownContent = "PROJECT.md not found"
                    }
                    return
                }

                let content = try String(contentsOf: manifestURL, encoding: .utf8)

                await MainActor.run {
                    projectMarkdownContent = content
                }
            } catch {
                await MainActor.run {
                    projectMarkdownContent = "Failed to load PROJECT.md: \(error.localizedDescription)"
                }
            }
        }
    }

    private func showInFinder(_ fileRef: ProjectFileReference) {
        Task {
            do {
                // Resolve project folder URL from bookmark
                guard let folderBookmark = project.sourceBookmarkData else {
                    showError("Project folder bookmark not found")
                    return
                }

                var isStale = false
                let bookmarkResolutionOptions: URL.BookmarkResolutionOptions = {
                    #if os(macOS)
                    return .withSecurityScope
                    #else
                    return []
                    #endif
                }()
                let projectURL = try URL(
                    resolvingBookmarkData: folderBookmark,
                    options: bookmarkResolutionOptions,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                // Start security-scoped access
                let didStartAccessing = projectURL.startAccessingSecurityScopedResource()
                defer {
                    if didStartAccessing {
                        projectURL.stopAccessingSecurityScopedResource()
                    }
                }

                // Construct file URL
                let fileURL = projectURL.appendingPathComponent(fileRef.relativePath)

                #if os(macOS)
                // Show in Finder on macOS
                NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                #else
                // On iOS, we could show a share sheet or open in Files app
                // For now, just show the path in an alert
                await showError("File location: \(fileURL.path)")
                #endif
            } catch {
                showError("Failed to show file in Finder: \(error.localizedDescription)")
            }
        }
    }

    private func loadAllFiles() {
        let unloadedFiles = project.fileReferences(in: .notLoaded)

        Task {
            for fileRef in unloadedFiles {
                loadFile(fileRef)
                // Small delay to avoid overwhelming the system
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    // MARK: - File Import

    private var supportedFileTypes: [UTType] {
        [
            UTType(filenameExtension: "fountain") ?? .plainText,
            UTType(filenameExtension: "fdx") ?? .xml,
            UTType(filenameExtension: "highland") ?? .zip,
            UTType(filenameExtension: "textbundle") ?? .bundle,
            UTType(filenameExtension: "markdown") ?? .plainText,
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "docx") ?? .data,
            UTType(filenameExtension: "odt") ?? .data,
            UTType(filenameExtension: "rtf") ?? .rtf,
            .pdf
        ]
    }

    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let sourceURL = urls.first else { return }
            Task {
                await importFile(from: sourceURL)
            }
        case .failure(let error):
            errorMessage = "File selection failed: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func importFile(from sourceURL: URL) async {
        // Start security-scoped access
        let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            // Resolve project folder URL from bookmark
            guard let folderBookmark = project.sourceBookmarkData else {
                showError("Project folder bookmark not found")
                return
            }

            var isStale = false
            let bookmarkResolutionOptions: URL.BookmarkResolutionOptions = {
                #if os(macOS)
                return .withSecurityScope
                #else
                return []
                #endif
            }()
            let projectURL = try URL(
                resolvingBookmarkData: folderBookmark,
                options: bookmarkResolutionOptions,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            // Start accessing project folder
            let didStartAccessingProject = projectURL.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessingProject {
                    projectURL.stopAccessingSecurityScopedResource()
                }
            }

            // Determine destination filename (handle conflicts)
            let filename = sourceURL.lastPathComponent
            var destinationURL = projectURL.appendingPathComponent(filename)

            // If file exists, append number to filename
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                let nameWithoutExtension = destinationURL.deletingPathExtension().lastPathComponent
                let ext = destinationURL.pathExtension
                var counter = 1

                repeat {
                    let newName = "\(nameWithoutExtension) \(counter).\(ext)"
                    destinationURL = projectURL.appendingPathComponent(newName)
                    counter += 1
                } while FileManager.default.fileExists(atPath: destinationURL.path)
            }

            // Copy file to project folder
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

            // Re-discover files to pick up the new file
            try projectService.syncProject(project)

            // Success feedback (implicit - file appears in list)
        } catch {
            showError("Failed to import file: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

// MARK: - Preview

#Preview {
    return {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: ProjectModel.self, ProjectFileReference.self,
            configurations: config
        )

        let project = ProjectModel(
            title: "My Series",
            author: "Jane Showrunner",
            projectDescription: "A multi-episode series",
            sourceType: .directory,
            sourceName: "My Series",
            sourceRootURL: "/tmp/my-series"
        )
        container.mainContext.insert(project)

        // Add sample file references
        let file1 = ProjectFileReference(
            relativePath: "episode-01.fountain",
            filename: "episode-01.fountain",
            fileExtension: "fountain"
        )
        file1.loadingState = .notLoaded
        file1.project = project

        let file2 = ProjectFileReference(
            relativePath: "episode-02.fountain",
            filename: "episode-02.fountain",
            fileExtension: "fountain"
        )
        file2.loadingState = .loaded
        file2.project = project

        container.mainContext.insert(file1)
        container.mainContext.insert(file2)

        return ProjectView(project: project)
            .modelContainer(container)
            .frame(width: 1000, height: 600)
    }()
}
