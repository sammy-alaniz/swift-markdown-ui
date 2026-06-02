import SwiftUI

struct InlineText: View {
  @Environment(\.inlineImageProvider) private var inlineImageProvider
  @Environment(\.baseURL) private var baseURL
  @Environment(\.imageBaseURL) private var imageBaseURL
  @Environment(\.softBreakMode) private var softBreakMode
  @Environment(\.theme) private var theme
  @Environment(\.markdownTextSelection) private var textSelection

  @State private var inlineImages: [String: Image] = [:]

  private let inlines: [InlineNode]

  init(_ inlines: [InlineNode]) {
    self.inlines = inlines
  }

  private var inlineTextStyles: InlineTextStyles {
    .init(
      code: self.theme.code,
      emphasis: self.theme.emphasis,
      strong: self.theme.strong,
      strikethrough: self.theme.strikethrough,
      link: self.theme.link
    )
  }

  private var hasImages: Bool {
    !Set(self.inlines.compactMap(\.imageData)).isEmpty
  }

  var body: some View {
    TextStyleAttributesReader { attributes in
      self.content(attributes)
    }
    .task(id: self.inlines) {
      self.inlineImages = (try? await self.loadInlineImages()) ?? [:]
    }
  }

  @ViewBuilder
  private func content(_ attributes: AttributeContainer) -> some View {
    #if canImport(UIKit)
    if #available(iOS 16.0, *), self.textSelection.isEnabled, !self.hasImages {
      SelectableTextView(
        attributedText: self.inlines.renderNSAttributedString(
          baseURL: self.baseURL,
          textStyles: self.inlineTextStyles,
          softBreakMode: self.softBreakMode,
          attributes: attributes
        ),
        configuration: self.textSelection
      )
    } else {
      self.plainText(attributes)
    }
    #else
    self.plainText(attributes)
    #endif
  }

  private func plainText(_ attributes: AttributeContainer) -> Text {
    self.inlines.renderText(
      baseURL: self.baseURL,
      textStyles: self.inlineTextStyles,
      images: self.inlineImages,
      softBreakMode: self.softBreakMode,
      attributes: attributes
    )
  }

  private func loadInlineImages() async throws -> [String: Image] {
    let images = Set(self.inlines.compactMap(\.imageData))
    guard !images.isEmpty else { return [:] }

    return try await withThrowingTaskGroup(of: (String, Image).self) { taskGroup in
      for image in images {
        guard let url = URL(string: image.source, relativeTo: self.imageBaseURL) else {
          continue
        }

        taskGroup.addTask {
          (image.source, try await self.inlineImageProvider.image(with: url, label: image.alt))
        }
      }

      var inlineImages: [String: Image] = [:]

      for try await result in taskGroup {
        inlineImages[result.0] = result.1
      }

      return inlineImages
    }
  }
}
