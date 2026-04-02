#if canImport(UIKit)
import UIKit

final class TriggerButton: UIButton {
    private let position: QuackbackPosition
    private var isOpen = false
    private let size: CGFloat = 48
    private let inset: CGFloat = 16

    init(position: QuackbackPosition, color: UIColor) {
        self.position = position; super.init(frame: .zero)
        backgroundColor = color; layer.cornerRadius = size / 2
        layer.shadowColor = UIColor.black.cgColor; layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowOpacity = 0.25; layer.shadowRadius = 4
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([widthAnchor.constraint(equalToConstant: size), heightAnchor.constraint(equalToConstant: size)])
        updateIcon(animated: false)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func install(in window: UIWindow) {
        window.addSubview(self)
        let guide = window.safeAreaLayoutGuide
        var constraints = [bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -inset)]
        switch position {
        case .bottomRight: constraints.append(trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -inset))
        case .bottomLeft: constraints.append(leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: inset))
        }
        NSLayoutConstraint.activate(constraints)
    }

    func setOpen(_ open: Bool) {
        guard open != isOpen else { return }; isOpen = open; updateIcon(animated: true)
    }

    private func updateIcon(animated: Bool) {
        let name = isOpen ? "xmark" : "bubble.left.fill"
        let img = UIImage(systemName: name)?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 20, weight: .medium))
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        if animated { UIView.transition(with: self, duration: 0.25, options: .transitionCrossDissolve) { self.setImage(img, for: .normal) } }
        else { setImage(img, for: .normal) }
    }
}
#endif
