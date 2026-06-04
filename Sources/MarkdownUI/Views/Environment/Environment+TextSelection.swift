import SwiftUI

/// A highlight color offered in the text selection menu.
public struct MarkdownHighlightColor: Identifiable, Equatable, Sendable {
  public let id: String
  public let name: String
  public let color: Color

  public init(id: String, name: String, color: Color) {
    self.id = id
    self.name = name
    self.color = color
  }
}

/// A persisted highlight, anchored to a block's plain text and a range within it.
public struct MarkdownHighlight: Identifiable, Equatable, Sendable {
  public let id: String
  public let blockText: String
  public let range: NSRange
  public let color: Color

  public init(id: String, blockText: String, range: NSRange, color: Color) {
    self.id = id
    self.blockText = blockText
    self.range = range
    self.color = color
  }
}

/// Information about a selection the reader chose to highlight.
public struct MarkdownTextSelectionEvent: Sendable {
  /// The full plain text of the block that was selected in.
  public let blockText: String
  /// The selected substring.
  public let selectedText: String
  /// The selected range within `blockText`.
  public let range: NSRange
}

struct MarkdownTextSelectionConfiguration {
  var isEnabled = false
  var selectionResetID = 0
  var highlightColors: [MarkdownHighlightColor] = []
  var highlights: [MarkdownHighlight] = []
  var onHighlight: ((MarkdownTextSelectionEvent, MarkdownHighlightColor) -> Void)?
  var onTapHighlight: ((MarkdownHighlight) -> Void)?
  var onTapText: (() -> Void)?
}

private struct MarkdownTextSelectionKey: EnvironmentKey {
  static let defaultValue = MarkdownTextSelectionConfiguration()
}

extension EnvironmentValues {
  var markdownTextSelection: MarkdownTextSelectionConfiguration {
    get { self[MarkdownTextSelectionKey.self] }
    set { self[MarkdownTextSelectionKey.self] = newValue }
  }
}

extension View {
  /// Enables text selection in rendered Markdown, with an optional "Highlight" menu.
  ///
  /// Selection works per text block (paragraph, heading, list item, …). When
  /// `highlightColors` and `onHighlight` are provided, the selection menu gains a
  /// "Highlight" submenu; choosing a color fires `onHighlight` so the host app can
  /// persist it. Persisted `highlights` are painted back onto matching blocks.
  ///
  /// - Note: Selection and highlighting are only available on iOS 16+. On other
  ///   platforms this modifier has no effect and Markdown renders as plain text.
  public func markdownTextSelection(
    enabled: Bool = true,
    selectionResetID: Int = 0,
    highlightColors: [MarkdownHighlightColor] = [],
    highlights: [MarkdownHighlight] = [],
    onHighlight: ((MarkdownTextSelectionEvent, MarkdownHighlightColor) -> Void)? = nil,
    onTapHighlight: ((MarkdownHighlight) -> Void)? = nil,
    onTapText: (() -> Void)? = nil
  ) -> some View {
    self.environment(
      \.markdownTextSelection,
      .init(
        isEnabled: enabled,
        selectionResetID: selectionResetID,
        highlightColors: highlightColors,
        highlights: highlights,
        onHighlight: onHighlight,
        onTapHighlight: onTapHighlight,
        onTapText: onTapText
      )
    )
  }
}
