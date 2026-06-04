# Select Test Task Selection

Branch target: `select-test`

Purpose: make MarkdownUI own Kindle-like Markdown text selection through a continuous selectable reader surface. This is a discrete task list, not an open-ended goal.

## Recommended First Slice

- [ ] Create branch `select-test` from current `main`.
- [ ] Add a new public `SelectableMarkdown` view.
- [ ] Back it with one non-editable, selectable `UITextView`.
- [ ] Render plain Markdown text into one continuous attributed string.
- [ ] Confirm native selection can cross paragraph boundaries.

Stop after this slice if cross-paragraph selection is not working.

## Task Selection

### Task 1: Add Public Reader Surface

- [ ] Add `SelectableMarkdown`.
- [ ] Keep existing `Markdown` behavior unchanged.
- [ ] Accept `markdown: String` input.
- [ ] Accept typography configuration needed by TextFlow.
- [ ] Add a minimal SwiftUI wrapper around the UIKit implementation.

Acceptance:

- `SelectableMarkdown("...")` compiles as a public MarkdownUI view.
- Existing `Markdown(...)` call sites remain source-compatible.

### Task 2: Continuous TextKit Rendering

- [ ] Create one `UITextView` for the whole document.
- [ ] Set `isEditable = false`.
- [ ] Set `isSelectable = true`.
- [ ] Set `isScrollEnabled = false` if TextFlow owns scrolling.
- [ ] Generate one `NSAttributedString` for the full Markdown document.

Acceptance:

- Selection can start in one paragraph and end in another.
- Native copy menu appears.
- Long press does not trigger TextFlow reader chrome.

### Task 3: Markdown To Attributed String

- [ ] Parse Markdown into a document tree.
- [ ] Render headings with larger/bolder text.
- [ ] Render paragraphs with body styling.
- [ ] Render strong/emphasis/code inline styles.
- [ ] Render links with link styling.
- [ ] Render lists as readable text with indentation.
- [ ] Render code blocks as monospaced blocks.
- [ ] Render blockquotes as readable prefixed or styled text.

Acceptance:

- Common converted PDF Markdown is readable.
- Selection range maps to the final rendered plain text.
- Tables and images may degrade gracefully in this first pass.

### Task 4: Document-Level Selection Events

- [ ] Add `MarkdownDocumentSelectionEvent`.
- [ ] Include `selectedText`.
- [ ] Include `range` in full rendered plain text.
- [ ] Include `documentText`.
- [ ] Expose an `onHighlight` callback using document-level ranges.

Acceptance:

- Highlight callback can represent multi-paragraph selections.
- TextFlow can persist selected text and `NSRange`.

### Task 5: Document-Level Highlights

- [ ] Add `MarkdownDocumentHighlight`.
- [ ] Store `id`, `range`, and `color`.
- [ ] Paint highlights into the attributed string.
- [ ] Update highlights without reparsing Markdown when possible.

Acceptance:

- A multi-paragraph highlight repaints after rerender.
- Existing block-level highlight APIs remain unchanged.

### Task 6: Tap And Selection Behavior

- [ ] Add `onTapText`.
- [ ] Add `onTapHighlight`.
- [ ] Add a clear-selection trigger or binding.
- [ ] Tap with active selection clears selection.
- [ ] Tap without active selection calls `onTapText`.
- [ ] Tap existing highlight calls `onTapHighlight`.

Acceptance:

- TextFlow can keep tap-to-show/hide reader chrome.
- TextFlow can clear selection without replacing the reader view.
- Highlight taps still open edit/remove UI.

### Task 7: Performance Pass

- [ ] Avoid reparsing Markdown for highlight-only changes.
- [ ] Cache rendered attributed text by Markdown hash and typography settings.
- [ ] Keep layout inside TextKit rather than SwiftUI block trees.
- [ ] Measure large converted PDFs before adding chunking.

Acceptance:

- Normal converted PDFs scroll smoothly.
- Font changes rebuild correctly.
- Highlight changes do not rebuild the full Markdown document unless necessary.

### Task 8: TextFlow Integration

- [ ] Replace TextFlow reader `Markdown(markdown)` with `SelectableMarkdown(markdown)`.
- [ ] Map TextFlow reader font family and size into MarkdownUI typography config.
- [ ] Persist new document-level highlights.
- [ ] Keep legacy block-level highlights readable during migration if possible.

Acceptance:

- TextFlow selection works across paragraphs.
- Reader chrome tap behavior still works.
- Long-press selection still works.
- Existing documents remain readable.

## Do Not Do Yet

- [ ] Do not remove the existing `Markdown` view.
- [ ] Do not rewrite all MarkdownUI rendering paths.
- [ ] Do not implement chunked virtualization before measuring one continuous `UITextView`.
- [ ] Do not migrate TextFlow persistence until `SelectableMarkdown` proves cross-paragraph selection.

