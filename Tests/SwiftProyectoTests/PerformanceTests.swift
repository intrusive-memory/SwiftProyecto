//
//  PerformanceTests.swift
//  SwiftProyectoTests
//
//  Performance benchmarks for SwiftProyecto operations.
//  These tests establish baselines and measure optimization improvements.
//

import XCTest
import SwiftData
@testable import SwiftProyecto
import SwiftCompartido

/// Performance test suite for SwiftProyecto library
///
/// Measures critical operations across the library to establish performance
/// baselines and track optimization efforts.
///
/// ## Test Categories
/// - Project Creation and Management
/// - File Discovery and Scanning
/// - Security-Scoped Bookmark Operations
/// - Lazy File Loading
/// - Project Synchronization
/// - ProjectMarkdownParser Operations
/// - ModelContainer Setup
/// - Concurrent Operations
/// - Memory Footprint
///
/// ## Running Performance Tests
/// ```bash
/// swift test --filter PerformanceTests
/// xcodebuild test -scheme SwiftProyecto -only-testing:SwiftProyectoTests/PerformanceTests
/// ```
///
/// ## Metrics Tracked
/// - XCTClockMetric: Wall clock time
/// - XCTCPUMetric: CPU usage
/// - XCTMemoryMetric: Memory allocations
/// - XCTStorageMetric: Disk I/O
///
final class PerformanceTests: XCTestCase {

    // MARK: - Test Configuration

    /// Number of iterations for repeated operations
    let iterationCount = 100

    /// Baseline metrics structure for comparison
    struct PerformanceBaseline: Codable {
        // Project operations
        var projectCreationTime: TimeInterval
        var projectScanTime: TimeInterval
        var projectSyncTime: TimeInterval

        // File operations
        var fileReferenceCreationTime: TimeInterval
        var fileLoadingTime: TimeInterval
        var lazyLoadingTime: TimeInterval

        // Bookmark operations
        var bookmarkCreationTime: TimeInterval
        var bookmarkResolutionTime: TimeInterval

        // Parser operations
        var markdownParseTime: TimeInterval
        var markdownGenerateTime: TimeInterval

        // SwiftData operations
        var modelContainerSetupTime: TimeInterval

        // Metadata
        var timestamp: Date
        var xcodeBuildNumber: String?
    }

    // MARK: - Project Model Performance

    func testProjectModelCreationPerformance() {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for i in 0..<100 {
                _ = ProjectModel(
                    title: "Test Project \(i)",
                    author: "Test Author"
                )
            }
        }
    }

    func testProjectFileReferenceCreationPerformance() {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for i in 0..<1000 {
                _ = ProjectFileReference(
                    relativePath: "episode-\(i).fountain",
                    filename: "episode-\(i).fountain",
                    fileExtension: "fountain"
                )
            }
        }
    }

    func testFileLoadingStateTransitionsPerformance() {
        let fileRef = ProjectFileReference(
            relativePath: "test.fountain",
            filename: "test.fountain",
            fileExtension: "fountain"
        )

        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<10000 {
                fileRef.loadingState = .notLoaded
                _ = fileRef.canLoad

                fileRef.loadingState = .loading
                _ = fileRef.isLoading

                fileRef.loadingState = .loaded
                _ = fileRef.isLoaded

                fileRef.loadingState = .stale
                _ = fileRef.needsReload

                fileRef.loadingState = .missing
                _ = fileRef.isMissing
            }
        }
    }

    // MARK: - ProjectMarkdownParser Performance

    func testProjectMarkdownParsingPerformance() throws {
        let markdown = """
        ---
        type: project
        title: My Series
        author: Jane Showrunner
        created: 2025-11-17T10:30:00Z
        description: A multi-episode series
        season: 1
        episodes: 12
        genre: Science Fiction
        tags: [sci-fi, drama, thriller]
        ---

        # Project Notes

        This is a test project for performance measurements.

        ## Production Schedule

        - Week 1: Pre-production
        - Week 2-10: Principal photography
        - Week 11-12: Post-production

        ## Budget Notes

        Total budget: $2M
        Per-episode: $166K
        """

        let parser = ProjectMarkdownParser()

        let metrics: [XCTMetric] = [
            XCTClockMetric(),
            XCTCPUMetric(),
            XCTMemoryMetric()
        ]

        let options = XCTMeasureOptions()
        options.iterationCount = 50

        measure(metrics: metrics, options: options) {
            do {
                _ = try parser.parse(markdown: markdown)
            } catch {
                XCTFail("Parse failed: \(error)")
            }
        }
    }

    func testProjectMarkdownGenerationPerformance() throws {
        let frontMatter = ProjectFrontMatter(
            title: "Performance Test Project",
            author: "Test Author",
            created: Date(),
            description: "A test project for performance benchmarking",
            season: 1,
            episodes: 12,
            genre: "Drama",
            tags: ["test", "performance", "benchmark"]
        )

        let body = """
        # Project Overview

        This is a test project used for performance benchmarking.

        ## Episodes

        1. Pilot Episode
        2. Episode Two
        3. Episode Three

        ## Production Notes

        Filming begins next month.
        """

        let parser = ProjectMarkdownParser()

        let metrics: [XCTMetric] = [
            XCTClockMetric(),
            XCTMemoryMetric()
        ]

        let options = XCTMeasureOptions()
        options.iterationCount = 100

        measure(metrics: metrics, options: options) {
            _ = parser.generate(frontMatter: frontMatter, body: body)
        }
    }

    // MARK: - SwiftData Performance

    func testModelContainerSetupPerformance() {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            _ = try? ModelContainer(
                for: ProjectModel.self, ProjectFileReference.self,
                configurations: config
            )
        }
    }

    func testProjectModelInsertionPerformance() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: ProjectModel.self, ProjectFileReference.self,
            configurations: config
        )

        let metrics: [XCTMetric] = [
            XCTClockMetric(),
            XCTMemoryMetric()
        ]

        let options = XCTMeasureOptions()
        options.iterationCount = 20

        measure(metrics: metrics, options: options) {
            // Insert 50 projects
            for i in 0..<50 {
                let project = ProjectModel(
                    title: "Project \(i)",
                    author: "Author \(i)"
                )
                container.mainContext.insert(project)
            }

            try? container.mainContext.save()

            // Clean up for next iteration
            try? container.mainContext.delete(model: ProjectModel.self)
        }
    }

    func testProjectWithFileReferencesPerformance() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: ProjectModel.self, ProjectFileReference.self,
            configurations: config
        )

        let metrics: [XCTMetric] = [
            XCTClockMetric(),
            XCTMemoryMetric()
        ]

        let options = XCTMeasureOptions()
        options.iterationCount = 10

        measure(metrics: metrics, options: options) {
            // Create project with 100 file references
            for projIndex in 0..<10 {
                let project = ProjectModel(
                    title: "Series \(projIndex)",
                    author: "Showrunner"
                )
                container.mainContext.insert(project)

                for fileIndex in 0..<100 {
                    let fileRef = ProjectFileReference(
                        relativePath: "episode-\(fileIndex).fountain",
                        filename: "episode-\(fileIndex).fountain",
                        fileExtension: "fountain"
                    )
                    fileRef.project = project
                    container.mainContext.insert(fileRef)
                }
            }

            try? container.mainContext.save()

            // Clean up
            try? container.mainContext.delete(model: ProjectModel.self)
            try? container.mainContext.delete(model: ProjectFileReference.self)
        }
    }

    func testProjectQueryPerformance() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: ProjectModel.self, ProjectFileReference.self,
            configurations: config
        )

        // Pre-populate with 100 projects
        for i in 0..<100 {
            let project = ProjectModel(
                title: "Project \(i)",
                author: i % 2 == 0 ? "Author A" : "Author B"
            )
            container.mainContext.insert(project)

            // Add 10 file references per project
            for j in 0..<10 {
                let fileRef = ProjectFileReference(
                    relativePath: "file-\(j).fountain",
                    filename: "file-\(j).fountain",
                    fileExtension: "fountain"
                )
                fileRef.project = project
                container.mainContext.insert(fileRef)
            }
        }
        try! container.mainContext.save()

        let metrics: [XCTMetric] = [
            XCTClockMetric(),
            XCTMemoryMetric()
        ]

        let options = XCTMeasureOptions()
        options.iterationCount = 50

        measure(metrics: metrics, options: options) {
            // Query projects by author
            let descriptor1 = FetchDescriptor<ProjectModel>(
                predicate: #Predicate { $0.author == "Author A" }
            )
            _ = try? container.mainContext.fetch(descriptor1)

            // Query all projects sorted by title
            let descriptor2 = FetchDescriptor<ProjectModel>(
                sortBy: [SortDescriptor(\.title)]
            )
            _ = try? container.mainContext.fetch(descriptor2)

            // Query file references
            let descriptor3 = FetchDescriptor<ProjectFileReference>(
                predicate: #Predicate { $0.fileExtension == "fountain" }
            )
            _ = try? container.mainContext.fetch(descriptor3)
        }
    }

    // MARK: - Relationship Performance

    func testProjectFileReferenceRelationshipPerformance() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: ProjectModel.self, ProjectFileReference.self,
            configurations: config
        )

        let project = ProjectModel(title: "Test Project", author: "Test Author")
        container.mainContext.insert(project)

        // Add 1000 file references
        for i in 0..<1000 {
            let fileRef = ProjectFileReference(
                relativePath: "file-\(i).fountain",
                filename: "file-\(i).fountain",
                fileExtension: "fountain"
            )
            fileRef.project = project
            container.mainContext.insert(fileRef)
        }

        try! container.mainContext.save()

        measure(metrics: [XCTClockMetric()]) {
            // Access file references through relationship
            _ = project.fileReferences.count
            _ = project.sortedFileReferences
            _ = project.totalFileCount
            _ = project.loadedFileCount
        }
    }

    func testFileLoadingStateFilteringPerformance() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: ProjectModel.self, ProjectFileReference.self,
            configurations: config
        )

        let project = ProjectModel(title: "Test Project", author: "Test Author")
        container.mainContext.insert(project)

        let loadingStates: [FileLoadingState] = [.notLoaded, .loading, .loaded, .stale, .missing]

        // Add 500 file references with various states
        for i in 0..<500 {
            let fileRef = ProjectFileReference(
                relativePath: "file-\(i).fountain",
                filename: "file-\(i).fountain",
                fileExtension: "fountain"
            )
            fileRef.loadingState = loadingStates[i % loadingStates.count]
            fileRef.project = project
            container.mainContext.insert(fileRef)
        }

        try! container.mainContext.save()

        measure(metrics: [XCTClockMetric()]) {
            _ = project.fileReferences(in: .notLoaded)
            _ = project.fileReferences(in: .loaded)
            _ = project.fileReferences(in: .stale)
            _ = project.fileReferences(in: .missing)
        }
    }

    // MARK: - Concurrent Operations Performance

    func testConcurrentProjectCreationPerformance() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: ProjectModel.self, ProjectFileReference.self,
            configurations: config
        )

        let metrics: [XCTMetric] = [
            XCTClockMetric(),
            XCTCPUMetric()
        ]

        let options = XCTMeasureOptions()
        options.iterationCount = 10

        measure(metrics: metrics, options: options) {
            let expectation = self.expectation(description: "Concurrent project creation")
            expectation.expectedFulfillmentCount = 10

            Task {
                await withTaskGroup(of: Void.self) { group in
                    for i in 0..<10 {
                        group.addTask {
                            let project = ProjectModel(
                                title: "Concurrent Project \(i)",
                                author: "Author \(i)"
                            )
                            await MainActor.run {
                                container.mainContext.insert(project)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }

    func testConcurrentMarkdownParsingPerformance() {
        let markdown = """
        ---
        type: project
        title: Concurrent Test
        author: Test
        created: 2025-11-17T10:30:00Z
        ---

        # Test
        """

        let parser = ProjectMarkdownParser()

        let metrics: [XCTMetric] = [
            XCTClockMetric(),
            XCTCPUMetric()
        ]

        let options = XCTMeasureOptions()
        options.iterationCount = 10

        measure(metrics: metrics, options: options) {
            let expectation = self.expectation(description: "Concurrent parsing")
            expectation.expectedFulfillmentCount = 20

            Task {
                await withTaskGroup(of: Void.self) { group in
                    for _ in 0..<20 {
                        group.addTask {
                            do {
                                _ = try parser.parse(markdown: markdown)
                                expectation.fulfill()
                            } catch {
                                XCTFail("Parse failed: \(error)")
                            }
                        }
                    }
                }
            }

            wait(for: [expectation], timeout: 10.0)
        }
    }

    // MARK: - Memory Footprint Tests

    func testLargeProjectMemoryFootprint() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: ProjectModel.self, ProjectFileReference.self,
            configurations: config
        )

        measure(metrics: [XCTMemoryMetric()]) {
            // Create a project with 10,000 file references
            let project = ProjectModel(
                title: "Large TV Series",
                author: "Prolific Writer"
            )
            container.mainContext.insert(project)

            for i in 0..<10000 {
                let fileRef = ProjectFileReference(
                    relativePath: "season-\(i / 100)/episode-\(i % 100).fountain",
                    filename: "episode-\(i).fountain",
                    fileExtension: "fountain"
                )
                fileRef.project = project
                container.mainContext.insert(fileRef)
            }

            try? container.mainContext.save()

            // Clean up
            try? container.mainContext.delete(model: ProjectModel.self)
            try? container.mainContext.delete(model: ProjectFileReference.self)
        }
    }

    func testMultipleProjectsMemoryFootprint() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: ProjectModel.self, ProjectFileReference.self,
            configurations: config
        )

        measure(metrics: [XCTMemoryMetric()]) {
            // Create 1000 projects with 10 files each
            for i in 0..<1000 {
                let project = ProjectModel(
                    title: "Project \(i)",
                    author: "Author \(i % 100)"
                )
                container.mainContext.insert(project)

                for j in 0..<10 {
                    let fileRef = ProjectFileReference(
                        relativePath: "file-\(j).fountain",
                        filename: "file-\(j).fountain",
                        fileExtension: "fountain"
                    )
                    fileRef.project = project
                    container.mainContext.insert(fileRef)
                }
            }

            try? container.mainContext.save()

            // Clean up
            try? container.mainContext.delete(model: ProjectModel.self)
            try? container.mainContext.delete(model: ProjectFileReference.self)
        }
    }

    // MARK: - Baseline Recording & Comparison

    func testRecordPerformanceBaseline() throws {
        print("""

        ==========================================
        PERFORMANCE BASELINE RECORDING
        ==========================================
        """)

        // Measure project creation
        let projectStart = Date()
        _ = ProjectModel(title: "Baseline Project", author: "Test")
        let projectTime = Date().timeIntervalSince(projectStart)

        // Measure file reference creation
        let fileRefStart = Date()
        for _ in 0..<100 {
            _ = ProjectFileReference(
                relativePath: "test.fountain",
                filename: "test.fountain",
                fileExtension: "fountain"
            )
        }
        let fileRefTime = Date().timeIntervalSince(fileRefStart) / 100.0

        // Measure markdown parsing
        let markdown = """
        ---
        type: project
        title: Test
        author: Test
        created: 2025-11-17T10:30:00Z
        ---

        # Notes
        """
        let parser = ProjectMarkdownParser()
        let parseStart = Date()
        _ = try parser.parse(markdown: markdown)
        let parseTime = Date().timeIntervalSince(parseStart)

        // Measure markdown generation
        let frontMatter = ProjectFrontMatter(title: "Test", author: "Test")
        let generateStart = Date()
        _ = parser.generate(frontMatter: frontMatter, body: "# Test")
        let generateTime = Date().timeIntervalSince(generateStart)

        // Measure ModelContainer setup
        let containerStart = Date()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        _ = try! ModelContainer(
            for: ProjectModel.self, ProjectFileReference.self,
            configurations: config
        )
        let containerTime = Date().timeIntervalSince(containerStart)

        let baseline = PerformanceBaseline(
            projectCreationTime: projectTime,
            projectScanTime: 0.0,  // Requires real filesystem
            projectSyncTime: 0.0,  // Requires real filesystem
            fileReferenceCreationTime: fileRefTime,
            fileLoadingTime: 0.0,  // Requires SwiftCompartido integration
            lazyLoadingTime: 0.0,  // Requires real filesystem
            bookmarkCreationTime: 0.0,  // Platform-specific
            bookmarkResolutionTime: 0.0,  // Platform-specific
            markdownParseTime: parseTime,
            markdownGenerateTime: generateTime,
            modelContainerSetupTime: containerTime,
            timestamp: Date(),
            xcodeBuildNumber: ProcessInfo.processInfo.operatingSystemVersionString
        )

        print("""
        Project Creation:         \(String(format: "%.6f", projectTime))s
        File Reference Creation:  \(String(format: "%.6f", fileRefTime))s
        Markdown Parse:           \(String(format: "%.4f", parseTime))s
        Markdown Generate:        \(String(format: "%.6f", generateTime))s
        ModelContainer Setup:     \(String(format: "%.4f", containerTime))s
        Timestamp:                \(baseline.timestamp)
        OS Version:               \(baseline.xcodeBuildNumber ?? "Unknown")
        ==========================================

        """)

        // Save baseline
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(baseline) {
            let tempDir = FileManager.default.temporaryDirectory
            let baselineFile = tempDir.appendingPathComponent("swiftproyecto_performance_baseline.json")
            try? data.write(to: baselineFile)
            print("Baseline saved to: \(baselineFile.path)")
        }
    }
}
