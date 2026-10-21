import UIKit
import VANavigator

#if canImport(UIKit.UIArrangementViewController) && !targetEnvironment(macCatalyst)
@available(iOS 27.1, *)
final class ArrangementExampleViewController: UIArrangementViewController {
    private weak var navigator: Navigator?
    private let isWindowRoot: Bool
    private var overlay = false
    private var horizontalOnly = false

    init(navigator: Navigator, isWindowRoot: Bool = false) {
        self.navigator = navigator
        self.isWindowRoot = isWindowRoot
        super.init()
        title = "Adaptive arrangement"
        setViewController(makeContent(primary: true), for: .primary)
        setViewController(makeContent(primary: false), for: .secondary)
        updateArrangement(.split)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        if !isWindowRoot {
            configureNavigation(in: self)
            navigationController?.setToolbarHidden(false, animated: false)
        }
    }

    private func configureNavigation(in controller: UIViewController) {
        controller.title = title
        controller.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: isWindowRoot ? "Main" : "Done",
            image: UIImage(systemName: isWindowRoot ? "house" : "checkmark"),
            primaryAction: UIAction { [weak self] _ in
                guard let self else { return }
                if isWindowRoot {
                    navigator?.navigate(destination: .identity(MainNavigationIdentity()), strategy: .replaceWindowRoot())
                } else if let navigationController {
                    navigator?.navigate(destination: .controller(navigationController), strategy: .closeIfTop())
                }
            }
        )
        controller.toolbarItems = [
            UIBarButtonItem(
                title: "Split / overlay",
                image: UIImage(systemName: "rectangle.on.rectangle"),
                primaryAction: UIAction { [weak self] _ in
                    guard let self else { return }
                    overlay.toggle()
                    applyArrangement()
                }
            ),
            .flexibleSpace(),
            UIBarButtonItem(
                title: "Limit axis",
                image: UIImage(systemName: "arrow.left.and.right"),
                primaryAction: UIAction { [weak self] _ in
                    guard let self else { return }
                    horizontalOnly.toggle()
                    applyArrangement()
                }
            ),
        ]
    }

    private func applyArrangement() {
        let axes: UIAxis = horizontalOnly ? .horizontal : [.horizontal, .vertical]
        if overlay {
            updateArrangement(.overlay.axes(axes), animated: true)
        } else {
            updateArrangement(.split.axes(axes), animated: true)
        }
        title = "\(overlay ? "Overlay" : "Split") · \(horizontalOnly ? "Horizontal" : "Both axes")"
        if isWindowRoot {
            for placement: ViewPlacement in [.primary, .secondary] {
                (viewController(for: placement) as? UINavigationController)?.viewControllers.first?.title = title
            }
        }
    }

    private func makeContent(primary: Bool) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = primary ? .secondarySystemBackground : .tertiarySystemBackground
        let label = UILabel()
        label.text = primary
            ? "Primary\nResize or fold the display. Use the toolbar to change the arrangement or limit it to the horizontal axis."
            : "Secondary\nYour text stays here while this placement is hidden."
        if isWindowRoot, primary {
            label.text? += "\nThe arrangement is the window root. Details open inside the frontmost panel."
        }
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        let textField = UITextField()
        textField.placeholder = "Try typing, then resize"
        textField.borderStyle = .roundedRect
        textField.accessibilityLabel = primary ? "Primary draft" : "Secondary draft"
        let push = Button(title: isWindowRoot ? "Push detail in frontmost panel" : "Push detail") { [weak self] _ in
            guard let self, let navigator, let origin = navigator.window?.topController else { return }
            let detail = UIViewController()
            detail.title = "Detail"
            detail.view.backgroundColor = .systemBackground
            let back = Button(title: "Return to arrangement") { [weak navigator, weak origin] _ in
                guard let origin else { return }
                navigator?.navigate(destination: .controller(origin), strategy: .closeToExisting)
            }
            detail.view.embedIntoScroll(back)
            navigator.navigate(destination: .controller(detail), strategy: .push())
        }
        controller.view.embedIntoScroll(label, textField, push)
        if isWindowRoot {
            configureNavigation(in: controller)
            let navigationController = UINavigationController(rootViewController: controller)
            navigationController.setToolbarHidden(false, animated: false)

            return navigationController
        }

        return controller
    }
}
#endif
