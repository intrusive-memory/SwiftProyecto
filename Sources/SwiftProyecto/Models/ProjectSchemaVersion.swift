//
//  ProjectSchemaVersion.swift
//  SwiftProyecto
//
//  The single source of truth for the PROJECT.md front-matter schema version.
//

import Foundation

/// The PROJECT.md front-matter schema version this library reads and writes.
///
/// The value is a monotonic integer. History:
/// - **3** (implicit): pre-versioned files. A document with no `schemaVersion:`
///   key is treated as v3.
/// - **4**: multi-season / multi-language / variants schema. Declared a typed
///   `cast:` roster.
/// - **5**: `cast:` is no longer a declared key. A production's cast lives in
///   `CAST.md`, owned by SwiftReparto; a legacy `cast:` block found in an older
///   PROJECT.md is preserved verbatim as an unknown key until the `proyecto`
///   CLI migrates it out via `reparto import`.
///
/// Every document this library emits is stamped with ``current`` — a legacy
/// file normalizes to the current version on its first write.
public enum ProjectSchemaVersion {
  /// The schema version stamped into every PROJECT.md this library writes.
  public static let current = 5
}
