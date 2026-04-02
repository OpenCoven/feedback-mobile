#if canImport(UIKit)
import UIKit

public enum Quackback {
    private static var config: QuackbackConfig?
    private static var wvManager: QuackbackWebView?
    private static var trigger: TriggerButton?
    private static var panel: PanelController?
    private static let emitter = EventEmitter()
    private static var isShowing = false
    private static var pendingIdentify: String?

    public static func configure(_ config: QuackbackConfig) { self.config = config }

    public static func identify(ssoToken: String) { enqueue(JSBridge.identifyCommand(ssoToken: ssoToken)) }
    public static func identify(userId: String, email: String, name: String? = nil, avatarURL: String? = nil) {
        enqueue(JSBridge.identifyCommand(userId: userId, email: email, name: name, avatarURL: avatarURL))
    }
    public static func logout() { enqueue(JSBridge.logoutCommand()) }

    public static func open(board: String? = nil) {
        guard let config else { return }; ensureWV(config)
        wvManager?.execute(JSBridge.openCommand(board: board)); presentPanel()
    }
    public static func close() { dismissPanel() }

    public static func showTrigger() {
        guard let config, trigger == nil else { return }
        let color = parseHex(config.buttonColor) ?? .systemBlue
        let btn = TriggerButton(position: config.position, color: color)
        btn.addTarget(self, action: #selector(triggerTapped), for: .touchUpInside)
        if let w = keyWindow { btn.install(in: w) }; trigger = btn
    }
    public static func hideTrigger() { trigger?.removeFromSuperview(); trigger = nil }

    @discardableResult
    public static func on(_ event: QuackbackEvent, handler: @escaping @Sendable ([String: Any]) -> Void) -> EventToken {
        emitter.on(event, handler: handler)
    }
    public static func off(_ token: EventToken) { emitter.off(token) }

    public static func destroy() {
        dismissPanel(); hideTrigger(); wvManager?.tearDown(); wvManager = nil
        emitter.removeAll(); config = nil; pendingIdentify = nil
    }

    private static func ensureWV(_ config: QuackbackConfig) {
        guard wvManager == nil else { return }
        let m = QuackbackWebView(config: config); m.delegate = Delegate.shared; wvManager = m
    }
    private static func enqueue(_ js: String) {
        if wvManager?.webView != nil { wvManager?.execute(js) } else { pendingIdentify = js }
    }
    private static func presentPanel() {
        guard !isShowing, let wvManager else { return }
        let pc = PanelController(webViewManager: wvManager)
        pc.onDismiss = { isShowing = false; trigger?.setOpen(false) }
        guard let top = topVC else { return }
        top.present(pc, animated: true); isShowing = true; trigger?.setOpen(true); panel = pc
    }
    private static func dismissPanel() {
        panel?.dismiss(animated: true); panel = nil; isShowing = false; trigger?.setOpen(false)
    }
    @objc private static func triggerTapped() { isShowing ? close() : open() }

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

    private final class Delegate: QuackbackWebViewDelegate {
        static let shared = Delegate()
        func webViewDidReceiveEvent(_ event: QuackbackEvent, data: [String: Any]) {
            if event == .close { dismissPanel() }; emitter.emit(event, data: data)
        }
        func webViewDidBecomeReady() {
            if let js = pendingIdentify { wvManager?.execute(js); pendingIdentify = nil }
        }
    }
}
#else
import Foundation

public enum Quackback {
    private static var config: QuackbackConfig?
    private static let emitter = EventEmitter()

    public static func configure(_ config: QuackbackConfig) { self.config = config }
    public static func identify(ssoToken: String) {}
    public static func identify(userId: String, email: String, name: String? = nil, avatarURL: String? = nil) {}
    public static func logout() {}
    public static func open(board: String? = nil) {}
    public static func close() {}
    public static func showTrigger() {}
    public static func hideTrigger() {}
    @discardableResult
    public static func on(_ event: QuackbackEvent, handler: @escaping @Sendable ([String: Any]) -> Void) -> EventToken {
        emitter.on(event, handler: handler)
    }
    public static func off(_ token: EventToken) { emitter.off(token) }
    public static func destroy() { emitter.removeAll(); config = nil }
}
#endif
