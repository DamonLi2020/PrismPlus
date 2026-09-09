# Architecture

## Initial vertical slice

```text
SwiftUI workspace
  ├─ Welcome and Explorer states
  │    ├─ full visible project resource tree
  │    ├─ .tex-only editor selection boundary
  │    └─ current-file LaTeX outline and source-line navigation
  ├─ Monaco LaTeX editor in a local-only WKWebView
  │    ├─ language configuration and snippets (TypeScript)
  │    └─ narrow Swift/JavaScript source and readiness bridge
  ├─ WorkspaceViewModel (@MainActor)
  │    └─ LaTeXCompiling protocol
  │         └─ TectonicCompiler actor
  │              ├─ TectonicCommandBuilder
  │              ├─ ProcessRunning boundary
  │              └─ isolated temporary build directory
  ├─ LaTeXDiagnosticParser and LaTeXOutlineParser
  └─ PDFKit preview and local PDF export boundary
```

Compilation is debounced, and an older task is cancelled when newer source arrives. The compiler
receives document content through a file in an isolated temporary directory and returns immutable
PDF data, diagnostics, and a full log. UI objects never own or operate a `Process` directly.

The editor follows VS Code's separation of concerns: Monaco owns editing behavior and rendering;
the LaTeX language module owns tokens, completion data, structural pairs, indentation, and
formatting. Formatting visually wraps source at the viewport and conservatively reflows plain
prose while preserving commands, comments, math, tables, and code-like environments. Vite packages
the editor into local application resources. A private read-only WebKit URL
scheme serves only files beneath that resource directory, so the editor needs no server or network.

PDF replacement is performed in place with animation disabled while preserving page, destination,
and zoom. Exported PDF data is written atomically either to a user-selected destination (starting
in Downloads) or beside the saved `.tex` source. Automatic builds are debounced and deferred while completion syntax or delimiters are
visibly incomplete. The initial workspace does not create or compile a document until the user
chooses a welcome-page action or selects a `.tex` resource.

## Planned extension points

- `ProjectStore`: multi-file workspaces, assets, templates, and recent projects.
- `AssistantProviding`: optional local or hosted AI without coupling the editor to one provider.
- `CompilationEngine`: optional `latexmk` compatibility alongside Tectonic.
- SyncTeX mapping for source-to-preview and preview-to-source navigation.

No service API is required for the local application. Any future sync or assistant service must be
specified separately as a versioned, resource-oriented REST API.
