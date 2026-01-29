import XCTest
@testable import SwiftProyecto
import SwiftData

final class ProjectServiceCastListTests: XCTestCase {
    var tempDirectory: URL!
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()

        // Create temp directory
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        // Create in-memory model container
        let schema = Schema([
            ProjectModel.self,
            ProjectFileReference.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    // MARK: - Character Extraction Tests

    @MainActor
    func testDiscoverCastList_SingleFile() async throws {
        // Create .fountain file with characters
        let fountainContent = """
        INT. TEMPLE - DAY

        NARRATOR
        In the beginning, there was the Tao.

        LAO TZU
        The Tao that can be told is not the eternal Tao.

        NARRATOR
        Wise words from the ancient master.
        """

        let episodeURL = tempDirectory.appendingPathComponent("episode-01.fountain")
        try fountainContent.write(to: episodeURL, atomically: true, encoding: .utf8)

        // Create project with file reference
        let projectService = ProjectService(modelContext: modelContext)
        let project = try projectService.createProject(
            at: tempDirectory,
            title: "Test Project",
            author: "Test Author"
        )

        // Add file reference manually
        let fileRef = ProjectFileReference(
            relativePath: "episode-01.fountain",
            filename: "episode-01",
            fileExtension: "fountain",
            lastKnownModificationDate: Date()
        )
        modelContext.insert(fileRef)
        project.fileReferences.append(fileRef)
        try modelContext.save()

        // Discover cast list
        let castList = try await projectService.discoverCastList(for: project)

        XCTAssertEqual(castList.count, 2)
        XCTAssertTrue(castList.contains { $0.character == "NARRATOR" })
        XCTAssertTrue(castList.contains { $0.character == "LAO TZU" })

        // All should have nil actor and empty voices
        for member in castList {
            XCTAssertNil(member.actor)
            XCTAssertEqual(member.voices, [])
        }
    }

    @MainActor
    func testDiscoverCastList_MultipleFiles() async throws {
        // Create multiple .fountain files
        let file1Content = """
        NARRATOR
        Episode one begins.

        BERNARD
        Hello there.
        """

        let file2Content = """
        NARRATOR
        Episode two begins.

        SYLVIA
        How are you?

        BERNARD
        I'm well, thanks.
        """

        let episode1URL = tempDirectory.appendingPathComponent("episode-01.fountain")
        let episode2URL = tempDirectory.appendingPathComponent("episode-02.fountain")

        try file1Content.write(to: episode1URL, atomically: true, encoding: .utf8)
        try file2Content.write(to: episode2URL, atomically: true, encoding: .utf8)

        // Create project with file references
        let projectService = ProjectService(modelContext: modelContext)
        let project = try projectService.createProject(
            at: tempDirectory,
            title: "Test Project",
            author: "Test Author"
        )

        let fileRef1 = ProjectFileReference(
            relativePath: "episode-01.fountain",
            filename: "episode-01",
            fileExtension: "fountain",
            lastKnownModificationDate: Date()
        )
        let fileRef2 = ProjectFileReference(
            relativePath: "episode-02.fountain",
            filename: "episode-02",
            fileExtension: "fountain",
            lastKnownModificationDate: Date()
        )

        modelContext.insert(fileRef1)
        modelContext.insert(fileRef2)
        project.fileReferences.append(fileRef1)
        project.fileReferences.append(fileRef2)
        try modelContext.save()

        // Discover cast list
        let castList = try await projectService.discoverCastList(for: project)

        XCTAssertEqual(castList.count, 3) // NARRATOR, BERNARD, SYLVIA
        XCTAssertTrue(castList.contains { $0.character == "NARRATOR" })
        XCTAssertTrue(castList.contains { $0.character == "BERNARD" })
        XCTAssertTrue(castList.contains { $0.character == "SYLVIA" })
    }

    @MainActor
    func testDiscoverCastList_EmptyProject() async throws {
        let projectService = ProjectService(modelContext: modelContext)
        let project = try projectService.createProject(
            at: tempDirectory,
            title: "Test Project",
            author: "Test Author"
        )

        let castList = try await projectService.discoverCastList(for: project)

        XCTAssertEqual(castList.count, 0)
    }

    @MainActor
    func testDiscoverCastList_IgnoresTransitions() async throws {
        let fountainContent = """
        INT. ROOM - DAY

        NARRATOR
        A scene begins.

        CUT TO:

        EXT. STREET - DAY
        """

        let episodeURL = tempDirectory.appendingPathComponent("episode-01.fountain")
        try fountainContent.write(to: episodeURL, atomically: true, encoding: .utf8)

        let projectService = ProjectService(modelContext: modelContext)
        let project = try projectService.createProject(
            at: tempDirectory,
            title: "Test Project",
            author: "Test Author"
        )

        let fileRef = ProjectFileReference(
            relativePath: "episode-01.fountain",
            filename: "episode-01",
            fileExtension: "fountain",
            lastKnownModificationDate: Date()
        )
        modelContext.insert(fileRef)
        project.fileReferences.append(fileRef)
        try modelContext.save()

        let castList = try await projectService.discoverCastList(for: project)

        XCTAssertEqual(castList.count, 1)
        XCTAssertEqual(castList.first?.character, "NARRATOR")
        XCTAssertFalse(castList.contains { $0.character == "CUT TO:" })
    }

    @MainActor
    func testDiscoverCastList_IgnoresSceneHeadings() async throws {
        let fountainContent = """
        INT. TEMPLE - DAY

        NARRATOR
        Scene begins.

        EXT. MOUNTAIN - NIGHT

        LAO TZU
        Under the stars.
        """

        let episodeURL = tempDirectory.appendingPathComponent("episode-01.fountain")
        try fountainContent.write(to: episodeURL, atomically: true, encoding: .utf8)

        let projectService = ProjectService(modelContext: modelContext)
        let project = try projectService.createProject(
            at: tempDirectory,
            title: "Test Project",
            author: "Test Author"
        )

        let fileRef = ProjectFileReference(
            relativePath: "episode-01.fountain",
            filename: "episode-01",
            fileExtension: "fountain",
            lastKnownModificationDate: Date()
        )
        modelContext.insert(fileRef)
        project.fileReferences.append(fileRef)
        try modelContext.save()

        let castList = try await projectService.discoverCastList(for: project)

        XCTAssertEqual(castList.count, 2)
        XCTAssertFalse(castList.contains { $0.character.hasPrefix("INT.") })
        XCTAssertFalse(castList.contains { $0.character.hasPrefix("EXT.") })
    }

    @MainActor
    func testDiscoverCastList_HandlesParentheticals() async throws {
        let fountainContent = """
        NARRATOR (V.O.)
        Voice over narration.

        BERNARD (CONT'D)
        Continued dialogue.

        SYLVIA (O.S.)
        Off-screen voice.
        """

        let episodeURL = tempDirectory.appendingPathComponent("episode-01.fountain")
        try fountainContent.write(to: episodeURL, atomically: true, encoding: .utf8)

        let projectService = ProjectService(modelContext: modelContext)
        let project = try projectService.createProject(
            at: tempDirectory,
            title: "Test Project",
            author: "Test Author"
        )

        let fileRef = ProjectFileReference(
            relativePath: "episode-01.fountain",
            filename: "episode-01",
            fileExtension: "fountain",
            lastKnownModificationDate: Date()
        )
        modelContext.insert(fileRef)
        project.fileReferences.append(fileRef)
        try modelContext.save()

        let castList = try await projectService.discoverCastList(for: project)

        // Should extract character names without parentheticals
        XCTAssertEqual(castList.count, 3)
        XCTAssertTrue(castList.contains { $0.character == "NARRATOR" })
        XCTAssertTrue(castList.contains { $0.character == "BERNARD" })
        XCTAssertTrue(castList.contains { $0.character == "SYLVIA" })
    }

    // MARK: - Merge Tests

    @MainActor
    func testMergeCastLists_PreservesExisting() {
        let projectService = ProjectService(modelContext: modelContext)

        let existing = [
            CastMember(
                character: "NARRATOR",
                actor: "Tom Stovall",
                voices: ["apple://en-US/Aaron"]
            ),
            CastMember(character: "OLD CHARACTER")
        ]

        let discovered = [
            CastMember(character: "NARRATOR"),
            CastMember(character: "NEW CHARACTER")
        ]

        let merged = projectService.mergeCastLists(discovered: discovered, existing: existing)

        XCTAssertEqual(merged.count, 3)

        // NARRATOR should preserve actor and voices
        let narrator = merged.first { $0.character == "NARRATOR" }
        XCTAssertEqual(narrator?.actor, "Tom Stovall")
        XCTAssertEqual(narrator?.voices, ["apple://en-US/Aaron"])

        // NEW CHARACTER should be added
        XCTAssertTrue(merged.contains { $0.character == "NEW CHARACTER" })

        // OLD CHARACTER should be preserved
        XCTAssertTrue(merged.contains { $0.character == "OLD CHARACTER" })
    }

    @MainActor
    func testMergeCastLists_Sorted() {
        let projectService = ProjectService(modelContext: modelContext)

        let existing = [
            CastMember(character: "ZULU"),
            CastMember(character: "ALPHA")
        ]

        let discovered = [
            CastMember(character: "CHARLIE"),
            CastMember(character: "BRAVO")
        ]

        let merged = projectService.mergeCastLists(discovered: discovered, existing: existing)

        // Should be sorted alphabetically
        XCTAssertEqual(merged[0].character, "ALPHA")
        XCTAssertEqual(merged[1].character, "BRAVO")
        XCTAssertEqual(merged[2].character, "CHARLIE")
        XCTAssertEqual(merged[3].character, "ZULU")
    }
}

