import SwiftUI
@preconcurrency import WebKit

struct MonacoEditorView: NSViewRepresentable {
    @Binding var text: String
    var formatRequestID: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
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
            formatRequestID: formatRequestID
        )

        webView.load(URLRequest(url: LocalEditorSchemeHandler.indexURL))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.update(source: text, formatRequestID: formatRequestID)
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
        @Binding private var text: String
        private weak var webView: WKWebView?
        private var schemeHandler: LocalEditorSchemeHandler?
        private var isReady = false
        private var pendingSource = ""
        private var lastSentSource = ""
        private var pendingFormatRequestID = 0
        private var lastFormatRequestID = 0

        init(text: Binding<String>) {
            _text = text
        }

        func attach(
            webView: WKWebView,
            schemeHandler: LocalEditorSchemeHandler,
            source: String,
            formatRequestID: Int
        ) {
            self.webView = webView
            self.schemeHandler = schemeHandler
            pendingSource = source
            pendingFormatRequestID = formatRequestID
        }

        func update(source: String, formatRequestID: Int) {
            pendingSource = source
            pendingFormatRequestID = formatRequestID
            synchronizeIfReady()
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            switch message.name {
            case "sourceChanged":
                guard let source = message.body as? String else { return }
                lastSentSource = source
                if text != source {
                    text = source
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

            if pendingFormatRequestID != lastFormatRequestID {
                lastFormatRequestID = pendingFormatRequestID
                webView.evaluateJavaScript("window.prismPlus?.format();")
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
