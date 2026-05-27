#if canImport(UIKit)
import UIKit

public enum OpenCovenFeedback {
    private static var config: OpenCovenFeedbackConfig?
    private static var wvManager: OpenCovenFeedbackWebView?
    private static var launcher: LauncherButton?
    private static var panel: PanelController?
    private static let emitter = EventEmitter()
    private static var isShowing = false
    private static var pendingIdentify: String?
    private static var serverThemeColor: UIColor?

    public static func configure(_ config: OpenCovenFeedbackConfig, identity: Identity? = nil) {
        self.config = config
        fetchTheme(instanceUrl: config.instanceUrl)
        if let identity { applyIdentity(identity) }
    }

    public static func identify() { enqueue(JSBridge.identifyAnonymousCommand()) }
    public static func identify(ssoToken: String) { enqueue(JSBridge.identifyCommand(ssoToken: ssoToken)) }
    public static func identify(userId: String, email: String, name: String? = nil, avatarURL: String? = nil) {
        enqueue(JSBridge.identifyCommand(userId: userId, email: email, name: name, avatarURL: avatarURL))
    }
    public static func logout() { enqueue(JSBridge.logoutCommand()) }

    /// Attach session metadata to feedback submitted through the widget.
    /// Pass `nil` as a value to remove a previously-set key.
    public static func metadata(_ patch: [String: String?]) {
        enqueue(JSBridge.metadataCommand(patch))
    }

    private static func applyIdentity(_ identity: Identity) {
        switch identity {
        case .user(let id, let email, let name, let avatarURL):
            identify(userId: id, email: email, name: name, avatarURL: avatarURL)
        case .ssoToken(let token): identify(ssoToken: token)
        }
    }

    public static func open(view: OpenView? = nil, title: String? = nil, board: String? = nil) {
        guard let config else { return }
        ensureWV(config)
        wvManager?.execute(JSBridge.openCommand(view: view, title: title, board: board))
        presentPanel()
    }
    public static func close() { dismissPanel() }

    public static func showLauncher() {
        guard let config, launcher == nil else { return }
        let color = resolveColor(config: config)
        let btn = LauncherButton(position: config.placement, color: color)
        btn.addTarget(self, action: #selector(launcherTapped), for: .touchUpInside)
        if let w = keyWindow { btn.install(in: w) }; launcher = btn
    }
    public static func hideLauncher() { launcher?.removeFromSuperview(); launcher = nil }

    @discardableResult
    public static func on(_ event: OpenCovenFeedbackEvent, handler: @escaping @Sendable ([String: Any]) -> Void) -> EventToken {
        emitter.on(event, handler: handler)
    }
    public static func off(_ token: EventToken) { emitter.off(token) }

    public static func destroy() {
        dismissPanel(); hideLauncher(); wvManager?.tearDown(); wvManager = nil
        emitter.removeAll(); config = nil; pendingIdentify = nil; serverThemeColor = nil
    }

    // MARK: - Private

    private static let defaultColor = UIColor(red: 99 / 255, green: 102 / 255, blue: 241 / 255, alpha: 1)

    private static func resolveColor(config: OpenCovenFeedbackConfig) -> UIColor {
        serverThemeColor ?? defaultColor
    }

    private static func fetchTheme(instanceUrl: URL) {
        let url = instanceUrl.appendingPathComponent("api/widget/config.json")
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let theme = json["theme"] as? [String: Any] else { return }

            let hex = theme["lightPrimary"] as? String
            guard let color = parseHex(hex) else { return }
            DispatchQueue.main.async {
                serverThemeColor = color
                launcher?.backgroundColor = color
            }
        }.resume()
    }

    private static func ensureWV(_ config: OpenCovenFeedbackConfig) {
        guard wvManager == nil else { return }
        let m = OpenCovenFeedbackWebView(config: config); m.delegate = Delegate.shared; wvManager = m
    }
    private static func enqueue(_ js: String) {
        if wvManager?.webView != nil { wvManager?.execute(js) } else { pendingIdentify = js }
    }
    private static func presentPanel() {
        guard !isShowing, let wvManager else { return }
        let pc = PanelController(webViewManager: wvManager)
        pc.onDismiss = { isShowing = false; launcher?.setOpen(false) }
        guard let top = topVC else { return }
        top.present(pc, animated: true); isShowing = true; launcher?.setOpen(true); panel = pc
    }
    private static func dismissPanel() {
        panel?.dismiss(animated: true); panel = nil; isShowing = false; launcher?.setOpen(false)
    }
    @objc private static func launcherTapped() { if isShowing { close() } else { open() } }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first { $0.isKeyWindow }
    }
    private static var topVC: UIViewController? {
        var vc = keyWindow?.rootViewController; while let p = vc?.presentedViewController { vc = p }; return vc
    }
    private static func parseHex(_ hex: String?) -> UIColor? {
        guard let hex, hex.hasPrefix("#"), hex.count == 7 else { return nil }
        var rgb: UInt64 = 0; Scanner(string: String(hex.dropFirst())).scanHexInt64(&rgb)
        return UIColor(red: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255, blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
    }

    private final class Delegate: OpenCovenFeedbackWebViewDelegate {
        static let shared = Delegate()
        func webViewDidReceiveEvent(_ event: OpenCovenFeedbackEvent, data: [String: Any]) {
            if event == .close { dismissPanel() }; emitter.emit(event, data: data)
        }
        func webViewDidBecomeReady() {
            if let js = pendingIdentify { wvManager?.execute(js); pendingIdentify = nil }
        }
    }
}
#else
import Foundation

public enum OpenCovenFeedback {
    private static var config: OpenCovenFeedbackConfig?
    private static let emitter = EventEmitter()

    public static func configure(_ config: OpenCovenFeedbackConfig, identity: Identity? = nil) { self.config = config }
    public static func identify() {}
    public static func identify(ssoToken: String) {}
    public static func identify(userId: String, email: String, name: String? = nil, avatarURL: String? = nil) {}
    public static func logout() {}
    public static func metadata(_ patch: [String: String?]) {}
    public static func open(view: OpenView? = nil, title: String? = nil, board: String? = nil) {}
    public static func close() {}
    public static func showLauncher() {}
    public static func hideLauncher() {}
    @discardableResult
    public static func on(_ event: OpenCovenFeedbackEvent, handler: @escaping @Sendable ([String: Any]) -> Void) -> EventToken {
        emitter.on(event, handler: handler)
    }
    public static func off(_ token: EventToken) { emitter.off(token) }
    public static func destroy() { emitter.removeAll(); config = nil }
}
#endif
