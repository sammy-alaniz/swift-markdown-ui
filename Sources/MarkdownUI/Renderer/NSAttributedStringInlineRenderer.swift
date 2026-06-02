#if canImport(UIKit)
import SwiftUI
import UIKit

extension Sequence where Element == InlineNode {
  /// Renders the inline sequence into an `NSAttributedString` with UIKit attributes,
  /// suitable for display in a selectable `UITextView`.
  ///
  /// Reuses MarkdownUI's `AttributedString` pipeline (so styling matches the SwiftUI
  /// `Text` rendering), then maps each run's `FontProperties` to a `UIFont` and its
  /// SwiftUI color to a `UIColor`.
  func renderNSAttributedString(
    baseURL: URL?,
    textStyles: InlineTextStyles,
    softBreakMode: SoftBreak.Mode,
    attributes: AttributeContainer
  ) -> NSAttributedString {
    let attributedString = self.renderAttributedString(
      baseURL: baseURL,
      textStyles: textStyles,
      softBreakMode: softBreakMode,
      attributes: attributes,
      resolvingFonts: false
    )

    let result = NSMutableAttributedString()

    for run in attributedString.runs {
      let substring = String(attributedString[run.range].characters)
      var uiAttributes: [NSAttributedString.Key: Any] = [:]

      if let fontProperties = run.fontProperties {
        uiAttributes[.font] = UIFont.withProperties(fontProperties)
      }
      if let color = run.foregroundColor {
        uiAttributes[.foregroundColor] = UIColor(color)
      }
      if let link = run.link {
        uiAttributes[.link] = link
      }

      result.append(NSAttributedString(string: substring, attributes: uiAttributes))
    }

    return result
  }
}
#endif
