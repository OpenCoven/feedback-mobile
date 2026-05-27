#if canImport(UIKit)
import UIKit

final class PanelController: UIViewController {
    private let webViewManager: OpenCovenFeedbackWebView
    var onDismiss: (() -> Void)?

    init(webViewManager: OpenCovenFeedbackWebView) {
        self.webViewManager = webViewManager; super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad(); webViewManager.loadIfNeeded()
        view.backgroundColor = .systemBackground
        guard let wv = webViewManager.webView else { return }
        wv.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(wv)
        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            wv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || presentingViewController == nil { onDismiss?() }
    }
}
#endif
