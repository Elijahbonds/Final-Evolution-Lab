import SwiftUI
import WebKit

/// CodeMirror-style web editor shell (bundled `editor.html`) with Swift ↔ JS bridge.
struct NexusStudioCodeEditorView: UIViewRepresentable {
    let content: String
    let language: NexusStudioLanguage
    let isReadOnly: Bool
    var onContentChange: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onContentChange: onContentChange)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "contentChanged")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.05, green: 0.07, blue: 0.09, alpha: 1)
        webView.scrollView.backgroundColor = webView.backgroundColor
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.loadEditorIfNeeded(in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onContentChange = onContentChange
        context.coordinator.pushContent(
            content,
            language: language,
            isReadOnly: isReadOnly,
            into: webView
        )
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var onContentChange: ((String) -> Void)?
        weak var webView: WKWebView?
        private var editorReady = false
        private var pendingContent: (String, NexusStudioLanguage, Bool)?

        init(onContentChange: ((String) -> Void)?) {
            self.onContentChange = onContentChange
        }

        func loadEditorIfNeeded(in webView: WKWebView) {
            guard let url = Bundle.main.url(forResource: "editor", withExtension: "html", subdirectory: "NexusStudio") else {
                webView.loadHTMLString(fallbackHTML, baseURL: nil)
                editorReady = true
                return
            }
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        func pushContent(_ text: String, language: NexusStudioLanguage, isReadOnly: Bool, into webView: WKWebView) {
            guard editorReady else {
                pendingContent = (text, language, isReadOnly)
                return
            }
            let b64 = Data(text.utf8).base64EncodedString()
            let js = "setStudioContentB64('\(b64)','\(language.rawValue)',\(isReadOnly ? "true" : "false"));"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            editorReady = true
            if let pending = pendingContent {
                pushContent(pending.0, language: pending.1, isReadOnly: pending.2, into: webView)
                pendingContent = nil
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "contentChanged", let text = message.body as? String else { return }
            onContentChange?(text)
        }

        private var fallbackHTML: String {
            """
            <html><body style='background:#0d1117;color:#c9d1d9;font-family:monospace;padding:12px;'>
            <pre>NEXUS Studio editor bundle missing.</pre>
            </body></html>
            """
        }
    }
}
