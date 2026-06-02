#if canImport(UIKit)
import SwiftUI
import UIKit

extension UIFont {
  /// Builds a `UIFont` from MarkdownUI `FontProperties`, mirroring
  /// `Font.withProperties(_:)` so selectable (TextKit) rendering matches the
  /// SwiftUI `Text` rendering.
  static func withProperties(_ fontProperties: FontProperties) -> UIFont {
    let size = round(fontProperties.size * fontProperties.scale)
    let weight = fontProperties.weight.uiFontWeight

    var font: UIFont
    switch fontProperties.family {
    case .system(let design):
      let base = UIFont.systemFont(ofSize: size, weight: weight)
      if let descriptor = base.fontDescriptor.withDesign(design.uiSystemDesign) {
        font = UIFont(descriptor: descriptor, size: size)
      } else {
        font = base
      }
    case .custom(let name):
      if let custom = UIFont(name: name, size: size) {
        font = custom
        if weight != .regular {
          let descriptor = custom.fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
          ])
          font = UIFont(descriptor: descriptor, size: size)
        }
      } else {
        font = UIFont.systemFont(ofSize: size, weight: weight)
      }
    }

    var traits = font.fontDescriptor.symbolicTraits
    if fontProperties.familyVariant == .monospaced {
      traits.insert(.traitMonoSpace)
    }
    if fontProperties.style == .italic {
      traits.insert(.traitItalic)
    }
    if traits != font.fontDescriptor.symbolicTraits,
      let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
    {
      font = UIFont(descriptor: descriptor, size: size)
    }

    return font
  }
}

extension Font.Weight {
  fileprivate var uiFontWeight: UIFont.Weight {
    switch self {
    case .ultraLight: return .ultraLight
    case .thin: return .thin
    case .light: return .light
    case .regular: return .regular
    case .medium: return .medium
    case .semibold: return .semibold
    case .bold: return .bold
    case .heavy: return .heavy
    case .black: return .black
    default: return .regular
    }
  }
}

extension Font.Design {
  fileprivate var uiSystemDesign: UIFontDescriptor.SystemDesign {
    switch self {
    case .default: return .default
    case .serif: return .serif
    case .rounded: return .rounded
    case .monospaced: return .monospaced
    @unknown default: return .default
    }
  }
}
#endif
