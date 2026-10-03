//
//  FileCoordinationManagerTests.swift
//  SwiftProyectoTests
//
//  Copyright (c) 2025 Intrusive Memory
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import Foundation
import XCTest

@testable import SwiftProyecto

/// Tests for FileCoordinationManager and coordinated writes with field preservation.
final class FileCoordinationManagerTests: XCTestCase {
  var tempDir: URL!
  let coordinator = FileCoordinationManager()
  let parser = ProjectMarkdownParser()

  override func setUp() {
    super.setUp()
    tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString
    )
    try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
  }

  override func tearDown() {
    try? FileManager.default.removeItem(at: tempDir)
    super.tearDown()
  }

  // MARK: - Test 5.4.1: Basic Coordinated Write

  /// Test that a coordinated write serializes access and modifies owned sections.
  func testCoordinatedWriteModifiesOwnedFields() throws {
    // Create initial PROJECT.md with personaje section
    let projectURL = tempDir.appendingPathComponent("PROJECT.md")
    var initial = ProjectFrontMatter(
      title: "Test Project",
      author: "Test Author",
      created: Date()
    )
    initial.appSections["personaje"] = try AnyCodable(["character": "Hero"])
    try parser.write(frontMatter: initial, body: "# Body", to: projectURL)

    // Personaje app writes to its owned section
    let ownedFields = FileCoordinationManager.OwnedFields(
      appName: "personaje",
      keys: ["personaje"]
    )
    try coordinator.coordinatedWrite(
      fileURL: projectURL,
      ownedFields: ownedFields,
      block: { mutable in
        mutable.appSections["personaje"] = try AnyCodable(["character": "Updated Hero"])
      }
    )

    // Verify changes persisted
    let (updated, _) = try parser.parse(fileURL: projectURL)
    XCTAssertNotNil(updated.appSections["personaje"])
  }

  // MARK: - Test 5.4.2: Field Preservation (Personaje + Vinetas)

  /// Test that Personaje preserves Vinetas' projects field during coordinated write.
  func testPersonajePreservesVinetasFields() throws {
    let projectURL = tempDir.appendingPathComponent("PROJECT.md")

    // Setup: Create file with both personaje and projects sections
    var initial = ProjectFrontMatter(
      title: "Multi-App Project",
      author: "Test Author",
      created: Date()
    )
    initial.appSections["personaje"] = try AnyCodable(["name": "Personaje A"])
    initial.appSections["projects"] = try AnyCodable(["episodes": 10])
    try parser.write(frontMatter: initial, body: "# Body", to: projectURL)

    // Personaje writes to its owned section only
    let personajeOwned = FileCoordinationManager.OwnedFields(
      appName: "personaje",
      keys: ["personaje"]
    )
    try coordinator.coordinatedWrite(
      fileURL: projectURL,
      ownedFields: personajeOwned,
      block: { mutable in
        mutable.appSections["personaje"] = try AnyCodable(["name": "Personaje B"])
      }
    )

    // Verify: Personaje field updated, projects field preserved
    let (after, _) = try parser.parse(fileURL: projectURL)
    XCTAssertNotNil(after.appSections["personaje"])
    XCTAssertNotNil(
      after.appSections["projects"],
      "projects field should be preserved after Personaje write")
  }

  /// Test that Vinetas preserves Personaje's personaje field during coordinated write.
  func testVinentasPreservesPersonajeFields() throws {
    let projectURL = tempDir.appendingPathComponent("PROJECT.md")

    // Setup: Create file with both sections
    var initial = ProjectFrontMatter(
      title: "Multi-App Project",
      author: "Test Author",
      created: Date()
    )
    initial.appSections["personaje"] = try AnyCodable(["name": "Hero"])
    initial.appSections["projects"] = try AnyCodable(["season": 1])
    try parser.write(frontMatter: initial, body: "# Body", to: projectURL)

    // Vinetas writes to its owned sections
    let vinetasOwned = FileCoordinationManager.OwnedFields(
      appName: "vinetas",
      keys: ["projects", "sequences"]
    )
    try coordinator.coordinatedWrite(
      fileURL: projectURL,
      ownedFields: vinetasOwned,
      block: { mutable in
        mutable.appSections["projects"] = try AnyCodable(["season": 2])
      }
    )

    // Verify: projects updated, personaje preserved
    let (after, _) = try parser.parse(fileURL: projectURL)
    XCTAssertNotNil(
      after.appSections["personaje"],
      "personaje field should be preserved after Vinetas write")
    XCTAssertNotNil(after.appSections["projects"])
  }

  // MARK: - Test 5.4.3: Write Cycles (P → V → P)

  /// Test alternating writes by Personaje and Vinetas preserve all data.
  func testWriteCyclePreservesAllData() throws {
    let projectURL = tempDir.appendingPathComponent("PROJECT.md")

    // Initial state: Personaje section only
    var initial = ProjectFrontMatter(
      title: "Cycle Test",
      author: "Test",
      created: Date()
    )
    initial.appSections["personaje"] = try AnyCodable(["pField": "P1"])
    try parser.write(frontMatter: initial, body: "# Body", to: projectURL)

    // Personaje writes
    let personajeOwned = FileCoordinationManager.OwnedFields(
      appName: "personaje",
      keys: ["personaje"]
    )
    try coordinator.coordinatedWrite(
      fileURL: projectURL,
      ownedFields: personajeOwned,
      block: { m in
        m.appSections["personaje"] = try AnyCodable(["pField": "P2"])
      }
    )

    // Vinetas writes
    let vinetasOwned = FileCoordinationManager.OwnedFields(
      appName: "vinetas",
      keys: ["projects", "sequences"]
    )
    try coordinator.coordinatedWrite(
      fileURL: projectURL,
      ownedFields: vinetasOwned,
      block: { m in
        m.appSections["projects"] = try AnyCodable(["vField": "V1"])
      }
    )

    // Personaje writes again
    try coordinator.coordinatedWrite(
      fileURL: projectURL,
      ownedFields: personajeOwned,
      block: { m in
        m.appSections["personaje"] = try AnyCodable(["pField": "P3"])
      }
    )

    // Verify: Both sections present
    let (final, _) = try parser.parse(fileURL: projectURL)
    XCTAssertNotNil(final.appSections["personaje"], "personaje section should exist")
    XCTAssertNotNil(final.appSections["projects"], "projects section should exist")
  }

  // MARK: - Test 5.4.4: Style Field Preservation

  /// Test that style field is fully preserved when not in owned keys.
  func testStylePreservationWhenNotOwned() throws {
    let projectURL = tempDir.appendingPathComponent("PROJECT.md")

    // Setup: Create file with style
    var initial = ProjectFrontMatter(
      title: "Style Test",
      author: "Test",
      created: Date(),
      style: Style(
        artStyle: "watercolor",
        palette: "warm",
        wardrobe: "period"
      )
    )
    initial.appSections["personaje"] = try AnyCodable(["art": "painting"])
    try parser.write(frontMatter: initial, body: "# Body", to: projectURL)

    // Personaje writes, but doesn't own style field
    let personajeOwned = FileCoordinationManager.OwnedFields(
      appName: "personaje",
      keys: ["personaje"],
      nestedPaths: []
    )
    try coordinator.coordinatedWrite(
      fileURL: projectURL,
      ownedFields: personajeOwned,
      block: { m in
        m.appSections["personaje"] = try AnyCodable(["art": "digital"])
      }
    )

    // Verify: style field is fully preserved
    let (after, _) = try parser.parse(fileURL: projectURL)
    XCTAssertEqual(
      after.style?.artStyle, "watercolor", "Full style should be preserved when not owned")
    XCTAssertEqual(after.style?.palette, "warm")
    XCTAssertEqual(after.style?.wardrobe, "period")
  }

  // MARK: - Integration Test: coordinatedWrite on Parser

  /// Test that ProjectMarkdownParser.coordinatedWrite convenience method works.
  func testParserCoordinatedWriteMethod() throws {
    let projectURL = tempDir.appendingPathComponent("PROJECT.md")

    // Create initial file
    var initial = ProjectFrontMatter(
      title: "Parser Test",
      author: "Test",
      created: Date()
    )
    initial.appSections["app1"] = try AnyCodable(["data": "value1"])
    try parser.write(frontMatter: initial, body: "# Body", to: projectURL)

    // Use parser's coordinatedWrite
    let owned = FileCoordinationManager.OwnedFields(appName: "app1", keys: ["app1"])
    try parser.coordinatedWrite(
      url: projectURL,
      ownedFields: owned,
      updatingOwnedFields: { m in
        m.appSections["app1"] = try AnyCodable(["data": "value2"])
      }
    )

    // Verify the section was updated
    let (result, _) = try parser.parse(fileURL: projectURL)
    XCTAssertNotNil(result.appSections["app1"])
  }

  // MARK: - Edge Cases

  /// Test coordinated write to a non-existent file throws an error.
  func testCoordinatedWriteToNonexistentFileThrows() throws {
    let projectURL = tempDir.appendingPathComponent("nonexistent.md")
    let owned = FileCoordinationManager.OwnedFields(appName: "test", keys: ["test"])

    var threwError = false
    do {
      try coordinator.coordinatedWrite(fileURL: projectURL, ownedFields: owned, block: { _ in })
    } catch {
      threwError = true
    }

    XCTAssertTrue(threwError, "coordinated write to nonexistent file should throw")
  }

  /// Test that coordinated write preserves body content.
  func testCoordinatedWritePreservesBody() throws {
    let projectURL = tempDir.appendingPathComponent("PROJECT.md")
    let originalBody = "# Original Body\n\nSome content here."

    var initial = ProjectFrontMatter(
      title: "Body Test",
      author: "Test",
      created: Date()
    )
    initial.appSections["test"] = try AnyCodable(["marker": "test"])
    try parser.write(frontMatter: initial, body: originalBody, to: projectURL)

    let owned = FileCoordinationManager.OwnedFields(appName: "test", keys: ["test"])
    try coordinator.coordinatedWrite(
      fileURL: projectURL,
      ownedFields: owned,
      block: { m in
        m.appSections["test"] = try AnyCodable(["marker": "updated"])
      }
    )

    let (_, body) = try parser.parse(fileURL: projectURL)
    XCTAssertEqual(body, originalBody)
  }
}
