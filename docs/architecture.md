# Architecture

## Initial vertical slice

```text
SwiftUI workspace
  ├─ Monaco LaTeX editor in a local-only WKWebView
  │    ├─ language configuration and snippets (TypeScript)
  │    └─ narrow, string-only Swift/JavaScript document bridge
  ├─ WorkspaceViewModel (@MainActor)
  │    └─ LaTeXCompiling protocol
  │         └─ TectonicCompiler actor
  │              ├─ TectonicCommandBuilder
  │              ├─ ProcessRunning boundary
  │              └─ isolated temporary build directory
  ├─ LaTeXDiagnosticParser
  └─ PDFKit preview
```

Compilation is debounced, and an older task is cancelled when newer source arrives. The compiler
receives document content through a file in an isolated temporary directory and returns immutable
PDF data, diagnostics, and a full log. UI objects never own or operate a `Process` directly.

The editor follows VS Code's separation of concerns: Monaco owns editing behavior and rendering;
the LaTeX language module owns tokens, completion data, structural pairs, indentation, and
formatting. Vite packages both into local application resources. A private read-only WebKit URL
scheme serves only files beneath that resource directory, so the editor needs no server or network.

PDF replacement is performed in place with animation disabled while preserving page, destination,
and zoom. Automatic builds are debounced and deferred while delimiters are visibly incomplete.

## Planned extension points

- `ProjectStore`: multi-file workspaces, assets, templates, and recent projects.
- `AssistantProviding`: optional local or hosted AI without coupling the editor to one provider.
- `CompilationEngine`: optional `latexmk` compatibility alongside Tectonic.
- SyncTeX mapping for source-to-preview and preview-to-source navigation.

No service API is required for the local application. Any future sync or assistant service must be
specified separately as a versioned, resource-oriented REST API.
