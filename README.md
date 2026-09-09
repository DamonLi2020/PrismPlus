# Prism Plus

Prism Plus is a local-first macOS LaTeX editor with a focused source editor, continuous safe
compilation, and a live PDF preview.

## Current milestone

The current vertical slice provides:

- a VS Code-style activity rail and project explorer with inline file/folder creation, contextual
  rename/reveal/trash actions, last-open-folder targeting, and `.tex`-only document opening;
- a welcome page with new-document, open-file, and open-folder actions;
- a split LaTeX source editor and PDF workspace after a document is opened;
- a resizable document outline with standard LaTeX heading hierarchy and click-to-jump navigation;
- an embedded offline Monaco editor—the same editor core used by VS Code;
- readable syntax highlighting, command suggestions, snippets, delimiter pairing, indentation,
  keyboard completion navigation, indented word wrapping, and conservative LaTeX-aware prose
  formatting;
- debounced local compilation through Tectonic;
- a stable PDFKit preview that preserves the current page, zoom, and scroll position;
- PDF download with a Downloads-folder default and one-click PDF creation beside saved sources;
- mandatory untrusted compilation with no shell invocation;
- compiler status, logs, clickable diagnostics, and VS Code-style red/yellow source markers;
- a reproducible Xcode project and test-first workflow.

## Requirements

- macOS 14 or newer
- Xcode 26 or newer
- Tectonic available at `/opt/homebrew/bin/tectonic`
- XcodeGen when regenerating the project
- Node.js 24 or newer only when changing or rebuilding the embedded editor

## Build

```sh
cd EditorWeb
npm install
npm test
npm run build
cd ..
xcodegen generate
xcodebuild test -project PrismPlus.xcodeproj -scheme PrismPlus -destination 'platform=macOS'
xcodebuild build -project PrismPlus.xcodeproj -scheme PrismPlus -destination 'platform=macOS'
```

The generated editor assets are included in the app bundle. Prism Plus performs no network request
to load the editor at runtime.

## Security

Prism Plus executes Tectonic directly with `--untrusted` and
`TECTONIC_UNTRUSTED_MODE=1`. It never builds a shell command from document text.

Third-party notices are recorded in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
