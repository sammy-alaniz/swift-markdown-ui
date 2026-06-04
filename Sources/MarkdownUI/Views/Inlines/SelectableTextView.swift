#if canImport(UIKit)
import SwiftUI
import UIKit

/// A non-editable, selectable `UITextView` that renders one Markdown text block,
/// adds a "Highlight" menu to the selection, and paints persisted highlights.
@available(iOS 16.0, *)
struct SelectableTextView: UIViewRepresentable {
  let attributedText: NSAttributedString
  let configuration: MarkdownTextSelectionConfiguration

  /// The block's plain text, used as the anchor for highlight persistence.
  private var blockText: String { attributedText.string }

  func makeCoordinator() -> Coordinator {
    Coordinator(configuration: configuration, blockText: blockText)
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
    let previousSelectionResetID = context.coordinator.configuration.selectionResetID
    context.coordinator.configuration = configuration
    context.coordinator.blockText = blockText

    let blockHighlights = configuration.highlights.filter { $0.blockText == blockText }
    context.coordinator.blockHighlights = blockHighlights

    if configuration.selectionResetID != previousSelectionResetID {
      textView.selectedTextRange = nil
      textView.resignFirstResponder()
    }

    let styled = NSMutableAttributedString(attributedString: attributedText)
    let fullLength = styled.length
    for highlight in blockHighlights {
      let range = highlight.range
      guard range.location >= 0, range.length > 0,
        range.location + range.length <= fullLength
      else { continue }
      styled.addAttribute(
        .backgroundColor,
        value: UIColor(highlight.color).withAlphaComponent(0.45),
        range: range
      )
    }

    if textView.attributedText != styled {
      textView.attributedText = styled
      textView.invalidateIntrinsicContentSize()
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
    var configuration: MarkdownTextSelectionConfiguration
    var blockText: String
    var blockHighlights: [MarkdownHighlight] = []
    weak var textView: UITextView?

    init(configuration: MarkdownTextSelectionConfiguration, blockText: String) {
      self.configuration = configuration
      self.blockText = blockText
    }

    func textView(
      _ textView: UITextView,
      editMenuForTextIn range: NSRange,
      suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
      guard configuration.isEnabled,
        let onHighlight = configuration.onHighlight,
        !configuration.highlightColors.isEmpty,
        range.length > 0
      else {
        return UIMenu(children: suggestedActions)
      }

      let colorActions = configuration.highlightColors.map { highlightColor in
        UIAction(
          title: highlightColor.name,
          image: UIImage(systemName: "circle.fill")?
            .withTintColor(UIColor(highlightColor.color), renderingMode: .alwaysOriginal)
        ) { [weak self] _ in
          guard let self, let textView = self.textView else { return }
          let nsText = textView.text as NSString
          guard range.location + range.length <= nsText.length else { return }
          let selected = nsText.substring(with: range)
          let event = MarkdownTextSelectionEvent(
            blockText: self.blockText,
            selectedText: selected,
            range: range
          )
          onHighlight(event, highlightColor)
          textView.selectedTextRange = nil
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
      guard configuration.isEnabled,
        let textView = gesture.view as? UITextView
      else { return }

      // Ignore taps while text is selected (let the selection UI handle it).
      if let selected = textView.selectedTextRange, !selected.isEmpty {
        textView.selectedTextRange = nil
        textView.resignFirstResponder()
        configuration.onTapText?()
        return
      }

      let point = gesture.location(in: textView)
      guard let position = textView.closestPosition(to: point) else { return }
      let index = textView.offset(from: textView.beginningOfDocument, to: position)

      if let hit = blockHighlights.first(where: { NSLocationInRange(index, $0.range) }),
        let onTapHighlight = configuration.onTapHighlight
      {
        onTapHighlight(hit)
      } else {
        configuration.onTapText?()
      }
    }
  }
}
#endif
