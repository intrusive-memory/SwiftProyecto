import SwiftUI
import XCTest

@testable import ProjectBrowser

/// Tests the two-tiered handler lookup in ``ProjectDetailPane``.
///
/// Handler lookup checks filename first (e.g., "PROJECT.md", "CAST.md")
/// before falling back to file extension (e.g., "md", "fountain").
/// This eliminates collisions where PROJECT.md and CAST.md both matched
/// the "md" extension handler.
///
/// The contract under test:
///
/// 1. **Name-based routing**: handlers["PROJECT.md"] routes only PROJECT.md
///    to its specific handler; other .md files use the extension handler.
/// 2. **Extension fallback**: handlers["md"] still routes other .md files
///    to the markdown handler when no name-based match exists.
/// 3. **Two-tier lookup**: Full handlers dict with mixed name and extension
///    entries routes each file to the correct handler.
@MainActor
final class ProjectDetailPaneHandlerLookupTests: XCTestCase {

  // MARK: - Name-Based Routing

  /// handlers["PROJECT.md"] routes only PROJECT.md to its specific handler.
  func testProjectMdHandlerRoutesByName() {
    let projectFile = ProjectFile(
      name: "PROJECT.md",
      relativePath: "PROJECT.md",
      fileExtension: "md",
      isDirectory: false,
      modifiedDate: Date(),
      fileSize: 100
    )

    let pane = ProjectDetailPane(
      selectedFile: projectFile,
      handlers: [
        "PROJECT.md": { file in
          AnyView(Text(verbatim: "PROJECT handler for \(file.name)"))
        }
      ]
    )

    XCTAssertEqual(pane.contentRoute(for: projectFile), .handler)
  }

  /// handlers["CAST.md"] routes only CAST.md to its specific handler.
  func testCastMdHandlerRoutesByName() {
    let castFile = ProjectFile(
      name: "CAST.md",
      relativePath: "CAST.md",
      fileExtension: "md",
      isDirectory: false,
      modifiedDate: Date(),
      fileSize: 200
    )

    let pane = ProjectDetailPane(
      selectedFile: castFile,
      handlers: [
        "CAST.md": { file in
          AnyView(Text(verbatim: "CAST handler for \(file.name)"))
        }
      ]
    )

    XCTAssertEqual(pane.contentRoute(for: castFile), .handler)
  }

  // MARK: - Extension Fallback

  /// handlers["md"] still routes other .md files to the markdown handler.
  func testExtensionHandlerFallbackForOtherMdFiles() {
    let otherMdFile = ProjectFile(
      name: "notes.md",
      relativePath: "docs/notes.md",
      fileExtension: "md",
      isDirectory: false,
      modifiedDate: Date(),
      fileSize: 150
    )

    let pane = ProjectDetailPane(
      selectedFile: otherMdFile,
      handlers: [
        "md": { file in
          AnyView(Text(verbatim: "Markdown handler for \(file.name)"))
        }
      ]
    )

    XCTAssertEqual(pane.contentRoute(for: otherMdFile), .handler)
  }

  /// Extension-only handlers work when there are no name-based entries.
  func testExtensionOnlyHandlerWithoutNameBasedEntries() {
    let fountainFile = ProjectFile(
      name: "script.fountain",
      relativePath: "episodes/script.fountain",
      fileExtension: "fountain",
      isDirectory: false,
      modifiedDate: Date(),
      fileSize: 5000
    )

    let pane = ProjectDetailPane(
      selectedFile: fountainFile,
      handlers: [
        "fountain": { file in
          AnyView(Text(verbatim: "Screenplay handler for \(file.name)"))
        }
      ]
    )

    XCTAssertEqual(pane.contentRoute(for: fountainFile), .handler)
  }

  // MARK: - Two-Tier Lookup

  /// Full handlers dict with name and extension entries routes each file
  /// to the correct handler.
  func testTwoTierLookupWithMixedNameAndExtensionHandlers() {
    let projectFile = ProjectFile(
      name: "PROJECT.md",
      relativePath: "PROJECT.md",
      fileExtension: "md",
      isDirectory: false,
      modifiedDate: Date(),
      fileSize: 100
    )

    let castFile = ProjectFile(
      name: "CAST.md",
      relativePath: "CAST.md",
      fileExtension: "md",
      isDirectory: false,
      modifiedDate: Date(),
      fileSize: 200
    )

    let notesFile = ProjectFile(
      name: "notes.md",
      relativePath: "docs/notes.md",
      fileExtension: "md",
      isDirectory: false,
      modifiedDate: Date(),
      fileSize: 150
    )

    let scriptFile = ProjectFile(
      name: "script.fountain",
      relativePath: "episodes/script.fountain",
      fileExtension: "fountain",
      isDirectory: false,
      modifiedDate: Date(),
      fileSize: 5000
    )

    let handlers: [String: (ProjectFile) -> AnyView] = [
      "PROJECT.md": { file in
        AnyView(Text(verbatim: "PROJECT handler"))
      },
      "CAST.md": { file in
        AnyView(Text(verbatim: "CAST handler"))
      },
      "md": { file in
        AnyView(Text(verbatim: "Markdown handler"))
      },
      "fountain": { file in
        AnyView(Text(verbatim: "Screenplay handler"))
      },
    ]

    // PROJECT.md → PROJECT.md handler (name match)
    let projectPane = ProjectDetailPane(selectedFile: projectFile, handlers: handlers)
    XCTAssertEqual(projectPane.contentRoute(for: projectFile), .handler)

    // CAST.md → CAST.md handler (name match)
    let castPane = ProjectDetailPane(selectedFile: castFile, handlers: handlers)
    XCTAssertEqual(castPane.contentRoute(for: castFile), .handler)

    // notes.md → md handler (extension match, no name match)
    let notesPane = ProjectDetailPane(selectedFile: notesFile, handlers: handlers)
    XCTAssertEqual(notesPane.contentRoute(for: notesFile), .handler)

    // script.fountain → fountain handler (extension match)
    let scriptPane = ProjectDetailPane(selectedFile: scriptFile, handlers: handlers)
    XCTAssertEqual(scriptPane.contentRoute(for: scriptFile), .handler)
  }

  // MARK: - Handler Execution

  /// The correct handler function is invoked for name-based matches.
  func testNameBasedHandlerIsInvoked() {
    var projectHandlerInvoked = false
    var extensionHandlerInvoked = false

    let projectFile = ProjectFile(
      name: "PROJECT.md",
      relativePath: "PROJECT.md",
      fileExtension: "md",
      isDirectory: false,
      modifiedDate: Date(),
      fileSize: 100
    )

    let pane = ProjectDetailPane(
      selectedFile: projectFile,
      handlers: [
        "PROJECT.md": { file in
          projectHandlerInvoked = true
          return AnyView(Text(verbatim: "PROJECT handler"))
        },
        "md": { file in
          extensionHandlerInvoked = true
          return AnyView(Text(verbatim: "Markdown handler"))
        },
      ]
    )

    // Force construction of the handler view
    _ = pane.contentView(for: projectFile)

    XCTAssertTrue(projectHandlerInvoked, "PROJECT.md handler must be invoked")
    XCTAssertFalse(extensionHandlerInvoked, "Extension handler must not be invoked for PROJECT.md")
  }

  /// The correct handler function is invoked for extension-based fallback.
  func testExtensionBasedHandlerIsInvokedWhenNoNameMatch() {
    var extensionHandlerInvoked = false

    let notesFile = ProjectFile(
      name: "notes.md",
      relativePath: "docs/notes.md",
      fileExtension: "md",
      isDirectory: false,
      modifiedDate: Date(),
      fileSize: 150
    )

    let pane = ProjectDetailPane(
      selectedFile: notesFile,
      handlers: [
        "PROJECT.md": { file in
          AnyView(Text(verbatim: "PROJECT handler"))
        },
        "md": { file in
          extensionHandlerInvoked = true
          return AnyView(Text(verbatim: "Markdown handler"))
        },
      ]
    )

    // Force construction of the handler view
    _ = pane.contentView(for: notesFile)

    XCTAssertTrue(extensionHandlerInvoked, "Extension handler must be invoked for notes.md")
  }

  // MARK: - Backwards Compatibility

  /// Extension-only handler registry still works (no name entries).
  func testExtensionOnlyHandlerRegistryStillWorks() {
    let mdFile = ProjectFile(
      name: "readme.md",
      relativePath: "readme.md",
      fileExtension: "md",
      isDirectory: false,
      modifiedDate: Date(),
      fileSize: 200
    )

    let txtFile = ProjectFile(
      name: "license.txt",
      relativePath: "license.txt",
      fileExtension: "txt",
      isDirectory: false,
      modifiedDate: Date(),
      fileSize: 300
    )

    let handlers: [String: (ProjectFile) -> AnyView] = [
      "md": { file in
        AnyView(Text(verbatim: "Markdown"))
      },
      "txt": { file in
        AnyView(Text(verbatim: "Text"))
      },
    ]

    let mdPane = ProjectDetailPane(selectedFile: mdFile, handlers: handlers)
    XCTAssertEqual(mdPane.contentRoute(for: mdFile), .handler)

    let txtPane = ProjectDetailPane(selectedFile: txtFile, handlers: handlers)
    XCTAssertEqual(txtPane.contentRoute(for: txtFile), .handler)
  }

  // MARK: - No Handler Cases

  /// No handler is found when neither name nor extension match.
  func testNoHandlerFoundWhenNeitherNameNorExtensionMatch() {
    let unknownFile = ProjectFile(
      name: "mystery.qqz",
      relativePath: "mystery.qqz",
      fileExtension: "qqz",
      isDirectory: false,
      modifiedDate: Date(),
      fileSize: 100
    )

    let pane = ProjectDetailPane(
      selectedFile: unknownFile,
      handlers: [
        "PROJECT.md": { file in
          AnyView(Text(verbatim: "PROJECT"))
        },
        "md": { file in
          AnyView(Text(verbatim: "Markdown"))
        },
      ]
    )

    // With no handler and no contents, should route to unsupported
    XCTAssertEqual(pane.contentRoute(for: unknownFile), .unsupported)
  }

  /// File with no extension (e.g., Makefile) can have a name-based handler.
  func testFileWithoutExtensionCanHaveNameBasedHandler() {
    let makefile = ProjectFile(
      name: "Makefile",
      relativePath: "Makefile",
      fileExtension: nil,
      isDirectory: false,
      modifiedDate: Date(),
      fileSize: 150
    )

    let pane = ProjectDetailPane(
      selectedFile: makefile,
      handlers: [
        "Makefile": { file in
          AnyView(Text(verbatim: "Makefile handler"))
        }
      ]
    )

    XCTAssertEqual(pane.contentRoute(for: makefile), .handler)
  }
}
