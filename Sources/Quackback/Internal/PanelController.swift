#if canImport(UIKit)
import UIKit

final class PanelController: UIViewController {
    private let webViewManager: QuackbackWebView
    var onDismiss: (() -> Void)?

    init(webViewManager: QuackbackWebView) {
        self.webViewManager = webViewManager; super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad(); webViewManager.loadIfNeeded()
        guard let wv = webViewManager.webView else { return }
        wv.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(wv)
        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: view.topAnchor),
            wv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]; sheet.prefersGrabberVisible = true
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || presentingViewController == nil { onDismiss?() }
    }
}
#endif
