//
//  ProyectoCLIValidateTests.swift
//  SwiftProyecto
//
//  Copyright (c) 2025 Intrusive Memory
//

import XCTest
import Foundation

/// Integration tests for the `proyecto validate` command.
///
/// These tests verify that the CLI validate command correctly:
/// - Accepts valid PROJECT.md files
/// - Rejects invalid PROJECT.md files with appropriate error messages
/// - Handles both directory and file path arguments
/// - Provides verbose output when requested
final class ProyectoCLIValidateTests: XCTestCase {

    var tempDirectory: URL!
    var proyectoBinary: URL!

    override func setUp() {
        super.setUp()

        // Create temporary test directory
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ValidateTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        // Find proyecto binary
        proyectoBinary = findProyectoBinary()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    // MARK: - Helper Methods

    /// Find the proyecto binary in the build products directory.
    private func findProyectoBinary() -> URL {
        // Check common build locations
        let possiblePaths = [
            // Xcode DerivedData (most common during development)
            URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Developer/Xcode/DerivedData")
                .appendingPathComponent("SwiftProyecto-*/Build/Products/Debug/proyecto", isDirectory: false),
            // Local bin directory (after make install)
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("bin/proyecto"),
            // .build directory (swift build)
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(".build/arm64-apple-macosx/debug/proyecto"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(".build/x86_64-apple-macosx/debug/proyecto"),
        ]

        // First try to find in DerivedData using shell expansion
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [
            "-c",
            "find ~/Library/Developer/Xcode/DerivedData/SwiftProyecto-* -name proyecto -type f 2>/dev/null | head -1"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()

        if let data = try? pipe.fileHandleForReading.readToEnd(),
           let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
            return URL(fileURLWithPath: path)
        }

        // Fall back to other locations
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path.path) {
                return path
            }
        }

        // If not found, return a placeholder that will cause tests to fail with a clear message
        return URL(fileURLWithPath: "/tmp/proyecto-not-found")
    }

    /// Execute the proyecto validate command.
    private func runValidate(arguments: [String] = []) -> (exitCode: Int32, stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = proyectoBinary
        process.arguments = ["validate"] + arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try? process.run()
        process.waitUntilExit()

        let stdoutData = try? stdoutPipe.fileHandleForReading.readToEnd()
        let stderrData = try? stderrPipe.fileHandleForReading.readToEnd()

        let stdout = stdoutData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let stderr = stderrData.flatMap { String(data: $0, encoding: .utf8) } ?? ""

        return (process.terminationStatus, stdout, stderr)
    }

    /// Create a PROJECT.md file in the temporary directory.
    private func createProjectMd(content: String) throws {
        let projectMdURL = tempDirectory.appendingPathComponent("PROJECT.md")
        try content.write(to: projectMdURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Test Cases - Valid PROJECT.md

    func testValidateValid_MinimalProjectMd() throws {
        // Verify binary exists
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: proyectoBinary.path),
            "proyecto binary not found at \(proyectoBinary.path). Run 'make build' first."
        )

        // Create valid PROJECT.md
        try createProjectMd(content: """
        ---
        type: project
        title: Test Project
        author: Test Author
        created: 2025-11-17T10:30:00Z
        ---

        Test body content.
        """)

        // Run validate
        let result = runValidate(arguments: [tempDirectory.path])

        // Verify success
        XCTAssertEqual(result.exitCode, 0, "Expected exit code 0 for valid PROJECT.md")
        XCTAssertTrue(result.stdout.contains("✅ Valid PROJECT.md"), "Expected success message")
        XCTAssertTrue(result.stdout.contains(tempDirectory.path), "Expected file path in output")
    }

    func testValidateValid_FullProjectMd() throws {
        // Verify binary exists
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: proyectoBinary.path),
            "proyecto binary not found at \(proyectoBinary.path). Run 'make build' first."
        )

        // Create full PROJECT.md with all fields
        try createProjectMd(content: """
        ---
        type: project
        title: Julius Caesar
        author: William Shakespeare
        created: 2025-11-17T10:30:00Z
        description: Shakespeare's tragedy of ambition and conspiracy
        season: 1
        episodes: 5
        genre: Drama
        tags: [podcast, shakespeare, tragedy]
        episodesDir: episodes
        audioDir: audio
        filePattern: "*.fountain"
        exportFormat: m4a
        ---

        # Julius Caesar

        A classic tragedy.
        """)

        // Run validate
        let result = runValidate(arguments: [tempDirectory.path])

        // Verify success
        XCTAssertEqual(result.exitCode, 0, "Expected exit code 0 for valid PROJECT.md")
        XCTAssertTrue(result.stdout.contains("✅ Valid PROJECT.md"), "Expected success message")
    }

    func testValidateValid_WithVerboseFlag() throws {
        // Verify binary exists
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: proyectoBinary.path),
            "proyecto binary not found at \(proyectoBinary.path). Run 'make build' first."
        )

        // Create valid PROJECT.md
        try createProjectMd(content: """
        ---
        type: project
        title: Test Project
        author: Test Author
        created: 2025-11-17T10:30:00Z
        description: Test description
        genre: Drama
        tags: [test, example]
        ---
        """)

        // Run validate with --verbose
        let result = runValidate(arguments: [tempDirectory.path, "--verbose"])

        // Verify success and verbose output
        XCTAssertEqual(result.exitCode, 0, "Expected exit code 0 for valid PROJECT.md")
        XCTAssertTrue(result.stdout.contains("✅ Valid PROJECT.md"), "Expected success message")
        XCTAssertTrue(result.stdout.contains("Parsed metadata:"), "Expected verbose header")
        XCTAssertTrue(result.stdout.contains("Type: project"), "Expected type in verbose output")
        XCTAssertTrue(result.stdout.contains("Title: Test Project"), "Expected title in verbose output")
        XCTAssertTrue(result.stdout.contains("Author: Test Author"), "Expected author in verbose output")
        XCTAssertTrue(result.stdout.contains("Genre: Drama"), "Expected genre in verbose output")
        XCTAssertTrue(result.stdout.contains("Tags: test, example"), "Expected tags in verbose output")
    }

    func testValidateValid_DirectFilePath() throws {
        // Verify binary exists
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: proyectoBinary.path),
            "proyecto binary not found at \(proyectoBinary.path). Run 'make build' first."
        )

        // Create valid PROJECT.md
        try createProjectMd(content: """
        ---
        type: project
        title: Test Project
        author: Test Author
        created: 2025-11-17T10:30:00Z
        ---
        """)

        let projectMdPath = tempDirectory.appendingPathComponent("PROJECT.md").path

        // Run validate with direct file path
        let result = runValidate(arguments: [projectMdPath])

        // Verify success
        XCTAssertEqual(result.exitCode, 0, "Expected exit code 0 for valid PROJECT.md")
        XCTAssertTrue(result.stdout.contains("✅ Valid PROJECT.md"), "Expected success message")
    }

    // MARK: - Test Cases - Invalid PROJECT.md

    func testValidateInvalid_MissingRequiredField() throws {
        // Verify binary exists
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: proyectoBinary.path),
            "proyecto binary not found at \(proyectoBinary.path). Run 'make build' first."
        )

        // Create PROJECT.md missing 'author' field
        try createProjectMd(content: """
        ---
        type: project
        title: Test Project
        created: 2025-11-17T10:30:00Z
        ---
        """)

        // Run validate
        let result = runValidate(arguments: [tempDirectory.path])

        // Verify failure
        XCTAssertNotEqual(result.exitCode, 0, "Expected non-zero exit code for invalid PROJECT.md")
        XCTAssertTrue(result.stdout.contains("❌ Invalid PROJECT.md"), "Expected error message")
        XCTAssertTrue(result.stdout.contains("Missing required field: author"), "Expected specific error about missing field")
    }

    func testValidateInvalid_MalformedYAML() throws {
        // Verify binary exists
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: proyectoBinary.path),
            "proyecto binary not found at \(proyectoBinary.path). Run 'make build' first."
        )

        // Create PROJECT.md with malformed YAML
        try createProjectMd(content: """
        ---
        type: project
        title: Test Project
        author: Test Author
        invalid yaml syntax [
        ---
        """)

        // Run validate
        let result = runValidate(arguments: [tempDirectory.path])

        // Verify failure
        XCTAssertNotEqual(result.exitCode, 0, "Expected non-zero exit code for malformed YAML")
        XCTAssertTrue(result.stdout.contains("❌ Invalid PROJECT.md"), "Expected error message")
        XCTAssertTrue(result.stdout.contains("Invalid YAML"), "Expected YAML error message")
    }

    func testValidateInvalid_NoFrontmatter() throws {
        // Verify binary exists
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: proyectoBinary.path),
            "proyecto binary not found at \(proyectoBinary.path). Run 'make build' first."
        )

        // Create PROJECT.md with no frontmatter
        try createProjectMd(content: """
        # Just a regular markdown file

        No YAML frontmatter here.
        """)

        // Run validate
        let result = runValidate(arguments: [tempDirectory.path])

        // Verify failure
        XCTAssertNotEqual(result.exitCode, 0, "Expected non-zero exit code for missing frontmatter")
        XCTAssertTrue(result.stdout.contains("❌ Invalid PROJECT.md"), "Expected error message")
        XCTAssertTrue(
            result.stdout.contains("No YAML front matter found"),
            "Expected error about missing frontmatter"
        )
    }

    func testValidateInvalid_MissingFile() throws {
        // Verify binary exists
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: proyectoBinary.path),
            "proyecto binary not found at \(proyectoBinary.path). Run 'make build' first."
        )

        // Don't create any PROJECT.md file

        // Run validate
        let result = runValidate(arguments: [tempDirectory.path])

        // Verify failure
        XCTAssertNotEqual(result.exitCode, 0, "Expected non-zero exit code when PROJECT.md not found")
        XCTAssertTrue(
            result.stderr.contains("PROJECT.md not found") || result.stdout.contains("PROJECT.md not found"),
            "Expected error about missing PROJECT.md"
        )
    }

    func testValidateInvalid_InvalidDateFormat() throws {
        // Verify binary exists
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: proyectoBinary.path),
            "proyecto binary not found at \(proyectoBinary.path). Run 'make build' first."
        )

        // Create PROJECT.md with invalid date format
        try createProjectMd(content: """
        ---
        type: project
        title: Test Project
        author: Test Author
        created: "not a valid date"
        ---
        """)

        // Run validate
        let result = runValidate(arguments: [tempDirectory.path])

        // Verify failure
        XCTAssertNotEqual(result.exitCode, 0, "Expected non-zero exit code for invalid date format")
        XCTAssertTrue(result.stdout.contains("❌ Invalid PROJECT.md"), "Expected error message")
        XCTAssertTrue(
            result.stdout.contains("Invalid YAML") || result.stdout.contains("date"),
            "Expected error about invalid date"
        )
    }
}
