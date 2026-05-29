#if canImport(UIKit)
import UIKit
import WebKit

protocol OpenCovenFeedbackWebViewDelegate: AnyObject {
    func webViewDidReceiveEvent(_ event: OpenCovenFeedbackEvent, data: [String: Any])
    func webViewDidBecomeReady()
}

final class OpenCovenFeedbackWebView: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    private(set) var webView: WKWebView?
    private let config: OpenCovenFeedbackConfig
    weak var delegate: OpenCovenFeedbackWebViewDelegate?
    private var isReady = false
    private var pendingCommands: [String] = []

    init(config: OpenCovenFeedbackConfig) { self.config = config; super.init() }

    func loadIfNeeded() {
        guard webView == nil else { return }
        let wkConfig = WKWebViewConfiguration()
        let ucc = WKUserContentController()
        ucc.addUserScript(WKUserScript(source: JSBridge.bridgeScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        ucc.add(self, name: "quackback")
        wkConfig.userContentController = ucc
        let wv = WKWebView(frame: .zero, configuration: wkConfig)
        wv.navigationDelegate = self; wv.isOpaque = false; wv.backgroundColor = .clear
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.load(URLRequest(url: config.widgetURL)); webView = wv
    }

    func execute(_ js: String) {
        guard isReady else { pendingCommands.append(js); return }
        webView?.evaluateJavaScript(js)
    }

    func tearDown() {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "quackback")
        webView?.stopLoading(); webView = nil; isReady = false; pendingCommands.removeAll()
    }

    func userContentController(_ uc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "quackback", let body = message.body as? String,
              let parsed = JSBridge.parseEvent(body) else { return }
        if parsed.event == .ready {
            isReady = true
            // Theme/config arrive via config.json + URL params — there is no init message.
            if let l = config.locale { webView?.evaluateJavaScript(JSBridge.localeCommand(l)) }
            pendingCommands.forEach { webView?.evaluateJavaScript($0) }; pendingCommands.removeAll()
            delegate?.webViewDidBecomeReady(); return
        }
        delegate?.webViewDidReceiveEvent(parsed.event, data: parsed.data)
    }

    func webView(_ wv: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if action.navigationType == .linkActivated, let url = action.request.url, url.host != config.instanceUrl.host {
            UIApplication.shared.open(url); decisionHandler(.cancel); return
        }
        decisionHandler(.allow)
    }
}
#endif
