import SwiftUI
@preconcurrency import WebKit

struct EditorNavigationRequest: Equatable {
    let id: Int
    let line: Int
}

struct MonacoEditorView: NSViewRepresentable {
    var text: String
    var formatRequestID: Int
    var navigationRequest: EditorNavigationRequest?
    var diagnostics: [CompilationDiagnostic]
    var onSourceChange: (String, Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(source: text, onSourceChange: onSourceChange)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "sourceChanged")
        configuration.userContentController.add(context.coordinator, name: "editorReady")

        guard
            let resourceRoot = Bundle.main.resourceURL?.appendingPathComponent(
                "EditorResources",
                isDirectory: true
            )
        else {
            return WKWebView(frame: .zero, configuration: configuration)
        }
        let schemeHandler = LocalEditorSchemeHandler(resourceRoot: resourceRoot)
        configuration.setURLSchemeHandler(
            schemeHandler, forURLScheme: LocalEditorSchemeHandler.scheme)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.attach(
            webView: webView,
            schemeHandler: schemeHandler,
            source: text,
            formatRequestID: formatRequestID,
            navigationRequest: navigationRequest,
            diagnostics: diagnostics
        )

        webView.load(URLRequest(url: LocalEditorSchemeHandler.indexURL))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.update(
            source: text,
            formatRequestID: formatRequestID,
            navigationRequest: navigationRequest,
            diagnostics: diagnostics,
            onSourceChange: onSourceChange
        )
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: "sourceChanged")
        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: "editorReady")
        webView.navigationDelegate = nil
    }

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        private weak var webView: WKWebView?
        private var schemeHandler: LocalEditorSchemeHandler?
        private var currentSource: String
        private var onSourceChange: (String, Bool) -> Void
        private var isReady = false
        private var pendingSource = ""
        private var lastSentSource = ""
        private var pendingFormatRequestID = 0
        private var lastFormatRequestID = 0
        private var pendingNavigationRequest: EditorNavigationRequest?
        private var lastNavigationRequestID = 0
        private var pendingDiagnostics: [CompilationDiagnostic] = []
        private var lastSentDiagnosticsJSON: String?

        init(source: String, onSourceChange: @escaping (String, Bool) -> Void) {
            currentSource = source
            self.onSourceChange = onSourceChange
        }

        func attach(
            webView: WKWebView,
            schemeHandler: LocalEditorSchemeHandler,
            source: String,
            formatRequestID: Int,
            navigationRequest: EditorNavigationRequest?,
            diagnostics: [CompilationDiagnostic]
        ) {
            self.webView = webView
            self.schemeHandler = schemeHandler
            pendingSource = source
            pendingFormatRequestID = formatRequestID
            pendingNavigationRequest = navigationRequest
            pendingDiagnostics = diagnostics
        }

        func update(
            source: String,
            formatRequestID: Int,
            navigationRequest: EditorNavigationRequest?,
            diagnostics: [CompilationDiagnostic],
            onSourceChange: @escaping (String, Bool) -> Void
        ) {
            currentSource = source
            self.onSourceChange = onSourceChange
            pendingSource = source
            pendingFormatRequestID = formatRequestID
            pendingNavigationRequest = navigationRequest
            pendingDiagnostics = diagnostics
            synchronizeIfReady()
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            switch message.name {
            case "sourceChanged":
                guard
                    let payload = message.body as? [String: Any],
                    let source = payload["source"] as? String
                else { return }
                let deferAutomaticCompilation =
                    payload["deferAutomaticCompilation"] as? Bool ?? false
                lastSentSource = source
                pendingSource = source
                if currentSource != source {
                    currentSource = source
                    onSourceChange(source, deferAutomaticCompilation)
                }
            case "editorReady":
                isReady = true
                synchronizeIfReady()
            default:
                break
            }
        }

        private func synchronizeIfReady() {
            guard isReady, let webView else { return }

            if pendingSource != lastSentSource {
                guard let sourceLiteral = try? Self.javaScriptString(pendingSource) else { return }
                lastSentSource = pendingSource
                webView.evaluateJavaScript("window.prismPlus?.setSource(\(sourceLiteral));")
            }

            if let diagnosticsJSON = try? Self.javaScriptDiagnostics(pendingDiagnostics),
                diagnosticsJSON != lastSentDiagnosticsJSON
            {
                lastSentDiagnosticsJSON = diagnosticsJSON
                webView.evaluateJavaScript(
                    "window.prismPlus?.setDiagnostics(\(diagnosticsJSON));"
                )
            }

            if pendingFormatRequestID != lastFormatRequestID {
                lastFormatRequestID = pendingFormatRequestID
                webView.evaluateJavaScript("window.prismPlus?.format();")
            }

            if let request = pendingNavigationRequest,
                request.id != lastNavigationRequestID
            {
                lastNavigationRequestID = request.id
                webView.evaluateJavaScript("window.prismPlus?.revealLine(\(request.line));")
            }
        }

        private static func javaScriptString(_ value: String) throws -> String {
            let data = try JSONEncoder().encode(value)
            guard let encoded = String(data: data, encoding: .utf8) else {
                throw EncodingError.invalidValue(
                    value,
                    EncodingError.Context(codingPath: [], debugDescription: "Invalid UTF-8")
                )
            }
            return encoded
        }

        private static func javaScriptDiagnostics(
            _ diagnostics: [CompilationDiagnostic]
        ) throws -> String {
            struct Payload: Encodable {
                let severity: String
                let message: String
                let line: Int?
            }

            let payloads = diagnostics.map {
                Payload(severity: $0.severity.rawValue, message: $0.message, line: $0.line)
            }
            let data = try JSONEncoder().encode(payloads)
            guard let encoded = String(data: data, encoding: .utf8) else {
                throw EncodingError.invalidValue(
                    diagnostics,
                    EncodingError.Context(codingPath: [], debugDescription: "Invalid UTF-8")
                )
            }
            return encoded
        }
    }

}

final class LocalEditorSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "prism-plus-editor"
    static let indexURL = URL(string: "\(scheme)://local/index.html")!

    private let resourceRoot: URL

    init(resourceRoot: URL) {
        self.resourceRoot = resourceRoot.standardizedFileURL
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard
            let requestURL = urlSchemeTask.request.url,
            requestURL.host == "local"
        else {
            fail(urlSchemeTask, code: .badURL)
            return
        }

        let relativePath = String(requestURL.path.drop(while: { $0 == "/" }))
        let fileURL = resourceRoot.appendingPathComponent(relativePath).standardizedFileURL
        guard fileURL.path.hasPrefix(resourceRoot.path + "/") else {
            fail(urlSchemeTask, code: .noPermissionsToReadFile)
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let response = URLResponse(
                url: requestURL,
                mimeType: Self.mimeType(for: fileURL.pathExtension),
                expectedContentLength: data.count,
                textEncodingName: fileURL.pathExtension == "html" ? "utf-8" : nil
            )
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private func fail(_ task: WKURLSchemeTask, code: URLError.Code) {
        task.didFailWithError(URLError(code))
    }

    private static func mimeType(for pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "html": "text/html"
        case "css": "text/css"
        case "js": "text/javascript"
        case "json": "application/json"
        default: "application/octet-stream"
        }
    }
}
