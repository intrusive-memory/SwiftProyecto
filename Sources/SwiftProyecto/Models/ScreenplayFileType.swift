import Foundation

/// The value of the `type:` front matter key a screenplay file declares.
///
/// Writers always emit this key, inferred from the role the file plays. Readers
/// never require it: a screenplay without `type:` still parses.
public enum ScreenplayFileType: String, Sendable, CaseIterable {

  /// A season episode script.
  case episode

  /// A season's intro, configured by `introFile`.
  case intro

  /// A season's outro, configured by `outroFile`.
  case outro

  /// Renders a complete `.fountain` document with a front matter block that
  /// declares this type, followed by a heading and a body.
  ///
  /// The output has no trailing newline, matching the placeholder writers it
  /// replaces.
  ///
  /// - Parameters:
  ///   - title: The `title:` front matter value.
  ///   - heading: The top-level Markdown heading in the body.
  ///   - body: The body text beneath the heading.
  public func placeholderDocument(title: String, heading: String, body: String) -> String {
    """
    ---
    type: \(rawValue)
    title: \(title)
    ---

    # \(heading)

    \(body)
    """
  }
}
