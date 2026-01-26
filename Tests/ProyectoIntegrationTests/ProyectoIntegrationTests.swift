import XCTest
@testable import SwiftProyecto

/// Integration tests for the `proyecto` CLI tool.
///
/// These tests verify end-to-end functionality by:
/// 1. Cloning a real podcast repository from intrusive-memory
/// 2. Running `proyecto init` to generate a PROJECT.md from scratch
/// 3. Parsing the generated PROJECT.md with ProjectMarkdownParser
/// 4. Verifying all required fields are present and valid
///
/// **Requirements:**
/// - The `proyecto` binary must be built and available in `./bin/proyecto`
/// - Network access to clone from GitHub
/// - An LLM model must be downloaded (uses default model)
///
/// **CI Setup:**
/// These tests run in a separate CI job that:
/// 1. Builds the proyecto binary with `make release`
/// 2. Downloads the default LLM model with `proyecto download`
/// 3. Runs these integration tests
final class ProyectoIntegrationTests: XCTestCase {

    var tempDirectory: URL!
    var parser: ProjectMarkdownParser!
    var proyectoBinaryPath: String!

    override func setUp() async throws {
        try await super.setUp()
        parser = ProjectMarkdownParser()

        // Create temp directory for test repos
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProyectoIntegrationTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        // Find proyecto binary - check multiple locations
        let possiblePaths = [
            "./bin/proyecto",
            "../bin/proyecto",
            "../../bin/proyecto",
            "/usr/local/bin/proyecto"
        ]

        proyectoBinaryPath = possiblePaths.first { path in
            FileManager.default.isExecutableFile(atPath: path)
        }

        // Skip if binary not found (allows unit tests to run without binary)
        try XCTSkipIf(proyectoBinaryPath == nil, "proyecto binary not found - skipping integration tests")
    }

    override func tearDown() async throws {
        // Clean up temp directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try await super.tearDown()
    }

    // MARK: - Integration Tests

    /// Tests that `proyecto init` can analyze a real podcast repository and generate
    /// a valid PROJECT.md that parses successfully.
    func testGenerateProjectMD_ForPodcastRepository() async throws {
        // Clone the podcast-meditations repository
        let repoURL = "https://github.com/intrusive-memory/podcast-meditations.git"
        let repoPath = tempDirectory.appendingPathComponent("podcast-meditations")

        try await cloneRepository(url: repoURL, to: repoPath)

        // Remove existing PROJECT.md to test generation from scratch
        let projectMdPath = repoPath.appendingPathComponent("PROJECT.md")
        if FileManager.default.fileExists(atPath: projectMdPath.path) {
            try FileManager.default.removeItem(at: projectMdPath)
        }

        // Verify PROJECT.md was removed
        XCTAssertFalse(FileManager.default.fileExists(atPath: projectMdPath.path),
                       "PROJECT.md should be removed before generation")

        // Run proyecto init to generate PROJECT.md
        try await runProyectoInit(in: repoPath)

        // Verify PROJECT.md was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: projectMdPath.path),
                      "PROJECT.md should be created by proyecto init")

        // Parse the generated PROJECT.md
        let (frontMatter, body) = try parser.parse(fileURL: projectMdPath)

        // Verify required fields are present
        XCTAssertEqual(frontMatter.type, "project", "type should be 'project'")
        XCTAssertFalse(frontMatter.title.isEmpty, "title should not be empty")
        XCTAssertFalse(frontMatter.author.isEmpty, "author should not be empty")
        XCTAssertNotNil(frontMatter.created, "created date should be present")

        // Verify the title contains something relevant (LLM should detect it's about Meditations)
        let titleLower = frontMatter.title.lowercased()
        let authorLower = frontMatter.author.lowercased()
        let descLower = (frontMatter.description ?? "").lowercased()

        let relevantTerms = ["meditation", "marcus", "aurelius", "stoic", "philosophy"]
        let hasRelevantContent = relevantTerms.contains { term in
            titleLower.contains(term) || authorLower.contains(term) || descLower.contains(term)
        }

        XCTAssertTrue(hasRelevantContent,
                      "Generated PROJECT.md should contain relevant terms for a Meditations podcast. " +
                      "Title: '\(frontMatter.title)', Author: '\(frontMatter.author)', " +
                      "Description: '\(frontMatter.description ?? "nil")'")

        // Log success details
        print("✅ Integration test passed!")
        print("   Title: \(frontMatter.title)")
        print("   Author: \(frontMatter.author)")
        print("   Description: \(frontMatter.description ?? "none")")
        print("   Genre: \(frontMatter.genre ?? "none")")
        print("   Tags: \(frontMatter.tags ?? [])")
        print("   Body length: \(body.count) characters")
    }

    /// Tests PROJECT.md generation for multiple podcast repositories.
    func testGenerateProjectMD_ForMultiplePodcasts() async throws {
        let repos = [
            "https://github.com/intrusive-memory/podcast-tao-de-jing.git",
            "https://github.com/intrusive-memory/podcast-meditations.git"
        ]

        for repoURL in repos {
            let repoName = URL(string: repoURL)!.deletingPathExtension().lastPathComponent
            let repoPath = tempDirectory.appendingPathComponent(repoName)

            print("Testing: \(repoName)")

            try await cloneRepository(url: repoURL, to: repoPath)

            // Remove existing PROJECT.md
            let projectMdPath = repoPath.appendingPathComponent("PROJECT.md")
            try? FileManager.default.removeItem(at: projectMdPath)

            // Generate new PROJECT.md
            try await runProyectoInit(in: repoPath)

            // Parse and verify
            let (frontMatter, _) = try parser.parse(fileURL: projectMdPath)

            XCTAssertEqual(frontMatter.type, "project")
            XCTAssertFalse(frontMatter.title.isEmpty, "\(repoName): title should not be empty")
            XCTAssertFalse(frontMatter.author.isEmpty, "\(repoName): author should not be empty")

            print("✅ \(repoName): \(frontMatter.title) by \(frontMatter.author)")
        }
    }

    // MARK: - Helpers

    /// Clones a git repository to the specified path.
    private func cloneRepository(url: String, to path: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["clone", "--depth", "1", url, path.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw IntegrationTestError.gitCloneFailed(url: url, output: output)
        }
    }

    /// Runs `proyecto init` in the specified directory.
    private func runProyectoInit(in directory: URL) async throws {
        guard let binaryPath = proyectoBinaryPath else {
            throw IntegrationTestError.binaryNotFound
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["init", directory.path, "--quiet"]
        process.currentDirectoryURL = directory

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw IntegrationTestError.proyectoInitFailed(output: output, exitCode: process.terminationStatus)
        }
    }

    // MARK: - Errors

    enum IntegrationTestError: LocalizedError {
        case binaryNotFound
        case gitCloneFailed(url: String, output: String)
        case proyectoInitFailed(output: String, exitCode: Int32)

        var errorDescription: String? {
            switch self {
            case .binaryNotFound:
                return "proyecto binary not found"
            case .gitCloneFailed(let url, let output):
                return "Failed to clone \(url): \(output)"
            case .proyectoInitFailed(let output, let exitCode):
                return "proyecto init failed (exit \(exitCode)): \(output)"
            }
        }
    }
}
