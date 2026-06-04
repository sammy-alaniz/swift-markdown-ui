import Foundation
import SwiftUI

/// Information about a document-level selection in ``SelectableMarkdown``.
public struct MarkdownDocumentSelectionEvent: Sendable {
  /// The selected substring.
  public let selectedText: String

  /// The selected range in the full rendered plain text.
  public let range: NSRange

  /// The full rendered plain text.
  public let documentText: String

  public init(selectedText: String, range: NSRange, documentText: String) {
    self.selectedText = selectedText
    self.range = range
    self.documentText = documentText
  }
}

/// A document-level highlight in ``SelectableMarkdown``.
public struct MarkdownDocumentHighlight: Identifiable, Equatable, Sendable {
  public let id: String
  public let range: NSRange
  public let color: Color

  public init(id: String, range: NSRange, color: Color) {
    self.id = id
    self.range = range
    self.color = color
  }
}

/// Typography values used by ``SelectableMarkdown``.
public struct SelectableMarkdownTypography {
  /// The base text font.
  public var font: FontProperties

  /// The base text color.
  public var foregroundColor: Color

  /// The link text color.
  public var linkColor: Color

  /// The inline-code background color.
  public var codeBackgroundColor: Color

  /// Creates typography values for selectable Markdown rendering.
  public init(
    font: FontProperties = .init(),
    foregroundColor: Color = .primary,
    linkColor: Color = .accentColor,
    codeBackgroundColor: Color = Color.secondary.opacity(0.18)
  ) {
    self.font = font
    self.foregroundColor = foregroundColor
    self.linkColor = linkColor
    self.codeBackgroundColor = codeBackgroundColor
  }
}

/// A continuous, selectable Markdown reader surface.
///
/// Unlike ``Markdown``, this view renders the document into one selectable text
/// surface so native text selection can cross paragraph boundaries.
@available(iOS 16.0, macCatalyst 16.0, *)
public struct SelectableMarkdown: View {
  private let markdown: String
  private let typography: SelectableMarkdownTypography
  private let highlights: [MarkdownDocumentHighlight]
  private let highlightColors: [MarkdownHighlightColor]
  private let selectionResetID: Int
  private let onHighlight: ((MarkdownDocumentSelectionEvent, MarkdownHighlightColor) -> Void)?
  private let onTapHighlight: ((MarkdownDocumentHighlight) -> Void)?
  private let onTapText: (() -> Void)?
  private let onSelectionCleared: (() -> Void)?

  /// Creates a selectable Markdown reader.
  public init(
    _ markdown: String,
    typography: SelectableMarkdownTypography = .init(),
    highlights: [MarkdownDocumentHighlight] = [],
    highlightColors: [MarkdownHighlightColor] = [],
    selectionResetID: Int = 0,
    onHighlight: ((MarkdownDocumentSelectionEvent, MarkdownHighlightColor) -> Void)? = nil,
    onTapHighlight: ((MarkdownDocumentHighlight) -> Void)? = nil,
    onTapText: (() -> Void)? = nil,
    onSelectionCleared: (() -> Void)? = nil
  ) {
    self.markdown = markdown
    self.typography = typography
    self.highlights = highlights
    self.highlightColors = highlightColors
    self.selectionResetID = selectionResetID
    self.onHighlight = onHighlight
    self.onTapHighlight = onTapHighlight
    self.onTapText = onTapText
    self.onSelectionCleared = onSelectionCleared
  }

  public var body: some View {
    #if canImport(UIKit) && !os(tvOS) && !os(watchOS)
    let base = SelectableMarkdownRenderCache.shared.baseAttributedText(
      markdown: self.markdown,
      typography: self.typography
    )
    SelectableMarkdownTextView(
      attributedText: Self.applyHighlights(self.highlights, to: base),
      documentText: base.string,
      highlights: self.highlights,
      highlightColors: self.highlightColors,
      selectionResetID: self.selectionResetID,
      onHighlight: self.onHighlight,
      onTapHighlight: self.onTapHighlight,
      onTapText: self.onTapText,
      onSelectionCleared: self.onSelectionCleared
    )
    #else
    Text(Self.renderPlainText(self.markdown))
    #endif
  }

  /// Renders Markdown to the same full plain text used for document selection ranges.
  public static func renderPlainText(_ markdown: String) -> String {
    SelectableMarkdownAttributedRenderer(markdown: markdown, typography: .init()).plainText
  }

  #if canImport(UIKit) && !os(tvOS) && !os(watchOS)
  private static func applyHighlights(
    _ highlights: [MarkdownDocumentHighlight],
    to base: NSAttributedString
  ) -> NSAttributedString {
    guard !highlights.isEmpty else { return base }

    let styled = NSMutableAttributedString(attributedString: base)
    let fullLength = styled.length
    for highlight in highlights {
      let range = highlight.range
      guard range.location >= 0,
        range.length > 0,
        range.location + range.length <= fullLength
      else { continue }

      styled.addAttribute(
        .backgroundColor,
        value: UIColor(highlight.color).withAlphaComponent(0.45),
        range: range
      )
    }
    return styled
  }
  #endif
}

#if canImport(UIKit) && !os(tvOS) && !os(watchOS)
@available(iOS 16.0, macCatalyst 16.0, *)
private struct SelectableMarkdownTextView: UIViewRepresentable {
  let attributedText: NSAttributedString
  let documentText: String
  let highlights: [MarkdownDocumentHighlight]
  let highlightColors: [MarkdownHighlightColor]
  let selectionResetID: Int
  let onHighlight: ((MarkdownDocumentSelectionEvent, MarkdownHighlightColor) -> Void)?
  let onTapHighlight: ((MarkdownDocumentHighlight) -> Void)?
  let onTapText: (() -> Void)?
  let onSelectionCleared: (() -> Void)?

  func makeCoordinator() -> Coordinator {
    Coordinator(
      documentText: documentText,
      highlights: highlights,
      highlightColors: highlightColors,
      selectionResetID: selectionResetID,
      onHighlight: onHighlight,
      onTapHighlight: onTapHighlight,
      onTapText: onTapText,
      onSelectionCleared: onSelectionCleared
    )
  }

  func makeUIView(context: Context) -> UITextView {
    let textView = UITextView()
    textView.isEditable = false
    textView.isSelectable = true
    textView.isScrollEnabled = false
    textView.backgroundColor = .clear
    textView.textContainerInset = .zero
    textView.textContainer.lineFragmentPadding = 0
    textView.adjustsFontForContentSizeCategory = false
    textView.delegate = context.coordinator
    textView.setContentCompressionResistancePriority(.required, for: .vertical)
    textView.setContentHuggingPriority(.required, for: .vertical)

    let tap = UITapGestureRecognizer(
      target: context.coordinator,
      action: #selector(Coordinator.handleTap(_:))
    )
    tap.cancelsTouchesInView = false
    textView.addGestureRecognizer(tap)

    context.coordinator.textView = textView
    return textView
  }

  func updateUIView(_ textView: UITextView, context: Context) {
    let previousSelectionResetID = context.coordinator.selectionResetID
    context.coordinator.documentText = documentText
    context.coordinator.highlights = highlights
    context.coordinator.highlightColors = highlightColors
    context.coordinator.selectionResetID = selectionResetID
    context.coordinator.onHighlight = onHighlight
    context.coordinator.onTapHighlight = onTapHighlight
    context.coordinator.onTapText = onTapText
    context.coordinator.onSelectionCleared = onSelectionCleared

    if textView.attributedText != attributedText {
      textView.attributedText = attributedText
      textView.invalidateIntrinsicContentSize()
    }

    if selectionResetID != previousSelectionResetID {
      context.coordinator.clearSelection(in: textView, notify: false)
    }
  }

  func sizeThatFits(
    _ proposal: ProposedViewSize,
    uiView: UITextView,
    context: Context
  ) -> CGSize? {
    let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? UIScreen.main.bounds.width
    let fitted = uiView.sizeThatFits(
      CGSize(width: width, height: .greatestFiniteMagnitude)
    )
    return CGSize(width: width, height: ceil(fitted.height))
  }

  final class Coordinator: NSObject, UITextViewDelegate {
    var documentText: String
    var highlights: [MarkdownDocumentHighlight]
    var highlightColors: [MarkdownHighlightColor]
    var selectionResetID: Int
    var onHighlight: ((MarkdownDocumentSelectionEvent, MarkdownHighlightColor) -> Void)?
    var onTapHighlight: ((MarkdownDocumentHighlight) -> Void)?
    var onTapText: (() -> Void)?
    var onSelectionCleared: (() -> Void)?
    weak var textView: UITextView?

    init(
      documentText: String,
      highlights: [MarkdownDocumentHighlight],
      highlightColors: [MarkdownHighlightColor],
      selectionResetID: Int,
      onHighlight: ((MarkdownDocumentSelectionEvent, MarkdownHighlightColor) -> Void)?,
      onTapHighlight: ((MarkdownDocumentHighlight) -> Void)?,
      onTapText: (() -> Void)?,
      onSelectionCleared: (() -> Void)?
    ) {
      self.documentText = documentText
      self.highlights = highlights
      self.highlightColors = highlightColors
      self.selectionResetID = selectionResetID
      self.onHighlight = onHighlight
      self.onTapHighlight = onTapHighlight
      self.onTapText = onTapText
      self.onSelectionCleared = onSelectionCleared
    }

    func textView(
      _ textView: UITextView,
      editMenuForTextIn range: NSRange,
      suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
      guard let onHighlight,
        !highlightColors.isEmpty,
        range.length > 0
      else {
        return UIMenu(children: suggestedActions)
      }

      let colorActions = highlightColors.map { highlightColor in
        UIAction(
          title: highlightColor.name,
          image: UIImage(systemName: "circle.fill")?
            .withTintColor(UIColor(highlightColor.color), renderingMode: .alwaysOriginal)
        ) { [weak self] _ in
          guard let self,
            let textView = self.textView,
            range.location >= 0,
            range.location + range.length <= (textView.text as NSString).length
          else { return }

          let selected = (textView.text as NSString).substring(with: range)
          let event = MarkdownDocumentSelectionEvent(
            selectedText: selected,
            range: range,
            documentText: self.documentText
          )
          onHighlight(event, highlightColor)
          self.clearSelection(in: textView, notify: true)
        }
      }

      let highlightMenu = UIMenu(
        title: "Highlight",
        image: UIImage(systemName: "highlighter"),
        children: colorActions
      )
      return UIMenu(children: [highlightMenu] + suggestedActions)
    }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
      guard gesture.state == .ended,
        let textView = gesture.view as? UITextView
      else { return }

      if hasActiveSelection(in: textView) {
        clearSelection(in: textView, notify: true)
        return
      }

      let point = gesture.location(in: textView)
      guard let position = textView.closestPosition(to: point) else {
        onTapText?()
        return
      }

      let index = textView.offset(from: textView.beginningOfDocument, to: position)
      if let hit = highlights.first(where: { NSLocationInRange(index, $0.range) }) {
        onTapHighlight?(hit)
      } else {
        onTapText?()
      }
    }

    func clearSelection(in textView: UITextView, notify: Bool) {
      let hadSelection = hasActiveSelection(in: textView)
      textView.selectedTextRange = nil
      textView.resignFirstResponder()
      if notify, hadSelection {
        onSelectionCleared?()
      }
    }

    private func hasActiveSelection(in textView: UITextView) -> Bool {
      guard let selected = textView.selectedTextRange else { return false }
      return !selected.isEmpty
    }
  }
}

private final class SelectableMarkdownRenderCache {
  static let shared = SelectableMarkdownRenderCache()

  private var storage: [SelectableMarkdownRenderKey: NSAttributedString] = [:]
  private let lock = NSLock()

  func baseAttributedText(
    markdown: String,
    typography: SelectableMarkdownTypography
  ) -> NSAttributedString {
    let key = SelectableMarkdownRenderKey(markdown: markdown, typography: typography)
    lock.lock()
    if let cached = storage[key] {
      lock.unlock()
      return cached
    }
    lock.unlock()

    let rendered = SelectableMarkdownAttributedRenderer(
      markdown: markdown,
      typography: typography
    )
    .attributedText

    lock.lock()
    storage[key] = rendered
    lock.unlock()
    return rendered
  }
}

private struct SelectableMarkdownRenderKey: Hashable {
  let markdown: String
  let font: FontProperties
  let foregroundColor: String
  let linkColor: String
  let codeBackgroundColor: String

  init(markdown: String, typography: SelectableMarkdownTypography) {
    self.markdown = markdown
    self.font = typography.font
    self.foregroundColor = String(describing: typography.foregroundColor)
    self.linkColor = String(describing: typography.linkColor)
    self.codeBackgroundColor = String(describing: typography.codeBackgroundColor)
  }
}
#endif

private struct SelectableMarkdownAttributedRenderer {
  let markdown: String
  let typography: SelectableMarkdownTypography

  var plainText: String {
    self.render().string
  }

  #if canImport(UIKit) && !os(tvOS) && !os(watchOS)
  var attributedText: NSAttributedString {
    self.render()
  }
  #endif

  private func render() -> NSMutableAttributedString {
    let output = NSMutableAttributedString()
    let blocks = Array<BlockNode>(markdown: markdown)
    self.append(blocks: blocks, to: output, listDepth: 0)
    return output
  }

  private func append(blocks: [BlockNode], to output: NSMutableAttributedString, listDepth: Int) {
    for block in blocks {
      switch block {
      case .heading(let level, let content):
        appendInline(
          content,
          to: output,
          font: headingFont(level: level),
          color: typography.foregroundColor
        )
        appendBreak(to: output, count: 2)

      case .paragraph(let content):
        appendInline(content, to: output, font: typography.font, color: typography.foregroundColor)
        appendBreak(to: output, count: 2)

      case .blockquote(let children):
        let nested = NSMutableAttributedString()
        append(blocks: children, to: nested, listDepth: listDepth)
        let quoted = nested.string
          .split(separator: "\n", omittingEmptySubsequences: false)
          .map { line in line.isEmpty ? ">" : "> \(line)" }
          .joined(separator: "\n")
        append(
          quoted.trimmingCharacters(in: .whitespacesAndNewlines),
          to: output,
          font: typography.font,
          color: typography.foregroundColor
        )
        appendBreak(to: output, count: 2)

      case .bulletedList(_, let items):
        for item in items {
          appendListItem(prefix: "•", children: item.children, to: output, listDepth: listDepth)
        }
        appendBreakIfNeeded(to: output)

      case .numberedList(_, let start, let items):
        for (offset, item) in items.enumerated() {
          appendListItem(
            prefix: "\(start + offset).",
            children: item.children,
            to: output,
            listDepth: listDepth
          )
        }
        appendBreakIfNeeded(to: output)

      case .taskList(_, let items):
        for item in items {
          appendListItem(
            prefix: item.isCompleted ? "[x]" : "[ ]",
            children: item.children,
            to: output,
            listDepth: listDepth
          )
        }
        appendBreakIfNeeded(to: output)

      case .codeBlock(_, let content):
        append(
          content.trimmingCharacters(in: .newlines),
          to: output,
          font: codeFont,
          color: typography.foregroundColor
        )
        appendBreak(to: output, count: 2)

      case .htmlBlock(let content):
        append(
          content.trimmingCharacters(in: .whitespacesAndNewlines),
          to: output,
          font: typography.font,
          color: typography.foregroundColor
        )
        appendBreak(to: output, count: 2)

      case .table(_, let rows):
        for row in rows {
          let cells = row.cells.map { $0.content.renderPlainText() }
          append(cells.joined(separator: " | "), to: output, font: typography.font, color: typography.foregroundColor)
          appendBreak(to: output, count: 1)
        }
        appendBreak(to: output, count: 1)

      case .thematicBreak:
        append("----------", to: output, font: typography.font, color: typography.foregroundColor)
        appendBreak(to: output, count: 2)
      }
    }
  }

  private func appendListItem(
    prefix: String,
    children: [BlockNode],
    to output: NSMutableAttributedString,
    listDepth: Int
  ) {
    append(String(repeating: "  ", count: listDepth) + "\(prefix) ", to: output, font: typography.font, color: typography.foregroundColor)
    append(blocks: children, to: output, listDepth: listDepth + 1)
  }

  private func appendInline(
    _ inlines: [InlineNode],
    to output: NSMutableAttributedString,
    font: FontProperties,
    color: Color
  ) {
    for inline in inlines {
      switch inline {
      case .text(let content):
        append(content, to: output, font: font, color: color)
      case .softBreak:
        append(" ", to: output, font: font, color: color)
      case .lineBreak:
        appendBreak(to: output, count: 1)
      case .code(let content):
        append(content, to: output, font: codeFont, color: color, backgroundColor: typography.codeBackgroundColor)
      case .html(let content):
        append(content, to: output, font: font, color: color)
      case .emphasis(let children):
        var styled = font
        styled.style = .italic
        appendInline(children, to: output, font: styled, color: color)
      case .strong(let children):
        var styled = font
        styled.weight = .semibold
        appendInline(children, to: output, font: styled, color: color)
      case .strikethrough(let children):
        let start = output.length
        appendInline(children, to: output, font: font, color: color)
        output.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: start, length: output.length - start))
      case .link(_, let children):
        appendInline(children, to: output, font: font, color: typography.linkColor)
      case .image(_, let children):
        let label = children.renderPlainText()
        append(label.isEmpty ? "[Image]" : "[Image: \(label)]", to: output, font: font, color: color)
      }
    }
  }

  private func append(
    _ string: String,
    to output: NSMutableAttributedString,
    font: FontProperties,
    color: Color,
    backgroundColor: Color? = nil
  ) {
    guard !string.isEmpty else { return }

    #if canImport(UIKit) && !os(tvOS) && !os(watchOS)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineBreakMode = .byWordWrapping
    paragraphStyle.lineSpacing = 4
    paragraphStyle.paragraphSpacing = 10

    var attributes: [NSAttributedString.Key: Any] = [
      .font: UIFont.withProperties(font),
      .foregroundColor: UIColor(color),
      .paragraphStyle: paragraphStyle,
    ]
    if let backgroundColor {
      attributes[.backgroundColor] = UIColor(backgroundColor).withAlphaComponent(0.55)
    }
    output.append(NSAttributedString(string: string, attributes: attributes))
    #else
    output.append(NSAttributedString(string: string))
    #endif
  }

  private func appendBreak(to output: NSMutableAttributedString, count: Int) {
    guard count > 0 else { return }
    output.append(NSAttributedString(string: String(repeating: "\n", count: count)))
  }

  private func appendBreakIfNeeded(to output: NSMutableAttributedString) {
    guard output.length > 0 else { return }
    if !output.string.hasSuffix("\n\n") {
      appendBreak(to: output, count: output.string.hasSuffix("\n") ? 1 : 2)
    }
  }

  private func headingFont(level: Int) -> FontProperties {
    var font = typography.font
    font.weight = .bold
    switch level {
    case 1: font.size *= 1.7
    case 2: font.size *= 1.45
    case 3: font.size *= 1.25
    default: font.size *= 1.12
    }
    return font
  }

  private var codeFont: FontProperties {
    var font = typography.font
    font.familyVariant = .monospaced
    font.size *= 0.92
    return font
  }
}

