#if canImport(UIKit)
import UIKit

final class MBIssueOverlayWindow: UIWindow {
    var interactiveFrame = CGRect.zero

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if rootViewController?.presentedViewController != nil {
            return super.hitTest(point, with: event)
        }
        guard !interactiveFrame.isEmpty, interactiveFrame.contains(point) else {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}

final class MBIssueOverlayRootViewController: UIViewController {
    override func loadView() {
        let container = UIView()
        container.backgroundColor = .clear
        view = container
    }

    func embed(_ child: UIViewController) {
        addChild(child)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        child.view.backgroundColor = .clear
        view.addSubview(child.view)
        NSLayoutConstraint.activate([
            child.view.topAnchor.constraint(equalTo: view.topAnchor),
            child.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            child.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        child.didMove(toParent: self)
    }
}
#endif
