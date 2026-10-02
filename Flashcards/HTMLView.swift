import SwiftUI
import WebKit

/// Renders an HTML string in a WKWebView with sensible default styling
/// (readable type, code blocks, responsive images, dark-mode aware).
///
/// Taps anywhere that isn't a link are forwarded through `onTap` via a
/// JavaScript click listener in the page. This is more reliable than a
/// UITapGestureRecognizer on the WKWebView itself, whose internal touch
/// handling can swallow taps before the recognizer sees them.
struct HTMLView: UIViewRepresentable {
    let html: String
    var onTap: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "cardTap")
        contentController.addUserScript(WKUserScript(
            source: Self.tapListenerJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true))
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onTap = onTap
        // Don't reload (and lose scroll position) on unrelated re-renders.
        if context.coordinator.lastHTML != html {
            context.coordinator.lastHTML = html
            webView.loadHTMLString(Self.wrapped(html), baseURL: nil)
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController
            .removeScriptMessageHandler(forName: "cardTap")
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        var onTap: (() -> Void)?
        var lastHTML: String?

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            if message.name == "cardTap" {
                onTap?()
            }
        }
    }

    /// Forwards taps to native code, but ignores taps on links so they
    /// still navigate normally. Taps inside embedded iframes (e.g. the
    /// solution video) go to the iframe, not the card.
    private static let tapListenerJS = """
        (function() {
            document.addEventListener('click', function(e) {
                var t = e.target;
                while (t && t.tagName !== 'A') { t = t.parentElement; }
                if (!t && window.webkit && window.webkit.messageHandlers
                        && window.webkit.messageHandlers.cardTap) {
                    window.webkit.messageHandlers.cardTap.postMessage('tap');
                }
            });
        })();
        """

    private static func wrapped(_ body: String) -> String {
        """
        <!DOCTYPE html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        :root { color-scheme: light dark; }
        body { font-family: -apple-system, system-ui, sans-serif; font-size: 17px;
               line-height: 1.55; margin: 0; padding: 4px 2px; }
        h2 { font-size: 22px; margin: 0 0 8px; }
        h3 { font-size: 17px; margin: 20px 0 8px; }
        pre { background: rgba(128,128,128,.16); padding: 12px; border-radius: 8px;
              overflow-x: auto; font-size: 14px; }
        code { font-family: ui-monospace, Menlo, monospace; font-size: .88em; }
        img { max-width: 100%; height: auto; border-radius: 8px; }
        table { border-collapse: collapse; margin: 8px 0; }
        td, th { border: 1px solid rgba(128,128,128,.5); padding: 6px 10px; font-size: 15px; }
        a { color: #0a84ff; }
        </style></head><body>\(body)</body></html>
        """
    }
}
