# Prism Plus development instructions

## Product constraints

- Build a local-first, native macOS LaTeX editor with SwiftUI, AppKit where needed, and PDFKit.
- Never invoke a TeX compiler through a shell. Pass arguments directly to `Process`.
- Always compile with Tectonic untrusted mode and keep shell escape disabled.
- Keep user documents local unless the user explicitly enables a network feature.
- If a network API is introduced, design it as a resource-oriented REST API with documented
  methods, status codes, JSON schemas, versioning, authentication, pagination, and errors.

## Engineering workflow

- Use test-driven development: write a failing behavioral test, implement the minimum change,
  then refactor while tests remain green.
- Prefer dependency injection and small protocols at process, filesystem, and network boundaries.
- Keep UI state on the main actor; move compilation and parsing work off the main actor.
- Treat warnings as defects when practical and never suppress errors without an explanation.
- Never commit API keys, tokens, generated PDFs, TeX intermediates, or user documents.

## Required checks

- Regenerate the project after editing `project.yml`: `xcodegen generate`.
- Format Swift: `xcrun swift-format format --in-place --recursive PrismPlus PrismPlusTests`.
- Run tests: `xcodebuild test -project PrismPlus.xcodeproj -scheme PrismPlus -destination 'platform=macOS'`.
- Build the app: `xcodebuild build -project PrismPlus.xcodeproj -scheme PrismPlus -destination 'platform=macOS'`.

