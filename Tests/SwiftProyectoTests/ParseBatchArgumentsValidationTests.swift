import Foundation
import XCTest

@testable import SwiftProyecto

/// Covers `ParseBatchArguments.validate()`, the input gate for batch generation.
final class ParseBatchArgumentsValidationTests: XCTestCase {

  func testNoConflictingFlagsPassValidation() throws {
    try ParseBatchArguments(projectPath: "/tmp/show").validate()
  }

  func testEachFlagAloneIsValid() throws {
    try ParseBatchArguments(projectPath: "/tmp/show", verbose: true).validate()
    try ParseBatchArguments(projectPath: "/tmp/show", quiet: true).validate()
    try ParseBatchArguments(projectPath: "/tmp/show", skipExisting: true).validate()
    try ParseBatchArguments(projectPath: "/tmp/show", regenerate: true).validate()
    try ParseBatchArguments(projectPath: "/tmp/show", useCastList: true).validate()
    try ParseBatchArguments(projectPath: "/tmp/show", castListPath: "CAST.md").validate()
  }

  func testVerboseAndQuietAreMutuallyExclusive() {
    let args = ParseBatchArguments(projectPath: "/tmp/show", verbose: true, quiet: true)

    XCTAssertThrowsError(try args.validate()) { error in
      XCTAssertEqual(
        error.localizedDescription,
        "Cannot use --verbose and --quiet together")
    }
  }

  func testSkipExistingAndRegenerateAreMutuallyExclusive() {
    let args = ParseBatchArguments(
      projectPath: "/tmp/show", skipExisting: true, regenerate: true)

    XCTAssertThrowsError(try args.validate()) { error in
      XCTAssertEqual(
        error.localizedDescription,
        "Cannot use --skip-existing and --regenerate together")
    }
  }

  func testUseCastListAndCastListPathAreMutuallyExclusive() {
    let args = ParseBatchArguments(
      projectPath: "/tmp/show", useCastList: true, castListPath: "CAST.md")

    XCTAssertThrowsError(try args.validate()) { error in
      XCTAssertEqual(
        error.localizedDescription,
        "Cannot use --use-cast-list and --cast-list together")
    }
  }

  func testProjectURLExpandsTildeAndStandardizes() {
    let args = ParseBatchArguments(projectPath: "~/Projects/show")

    XCTAssertTrue(args.projectURL.path.hasPrefix(NSHomeDirectory()))
    XCTAssertFalse(args.projectURL.path.contains("~"))
    XCTAssertTrue(args.projectURL.isFileURL)
  }
}
