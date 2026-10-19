import UIKit
import VANavigator

#if canImport(UIKit.UIArrangementViewController) && !targetEnvironment(macCatalyst)
@available(iOS 27.1, *)
final class ArrangementExampleViewController: UIArrangementViewController {
    private weak var navigator: Navigator?
    private var overlay = false
    private var horizontalOnly = false

    init(navigator: Navigator) {
        self.navigator = navigator
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
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Done", image: UIImage(systemName: "checkmark"),
            primaryAction: UIAction { [weak self] _ in
                guard let self, let navigationController else { return }
                navigator?.navigate(destination: .controller(navigationController), strategy: .closeIfTop())
            }
        )
        toolbarItems = [
            UIBarButtonItem(title: "Split / overlay", image: UIImage(systemName: "rectangle.on.rectangle"),
                primaryAction: UIAction { [weak self] _ in
                    guard let self else { return }
                    overlay.toggle()
                    applyArrangement()
                }),
            .flexibleSpace(),
            UIBarButtonItem(title: "Limit axis", image: UIImage(systemName: "arrow.left.and.right"),
                primaryAction: UIAction { [weak self] _ in
                    guard let self else { return }
                    horizontalOnly.toggle()
                    applyArrangement()
                }),
        ]
        navigationController?.setToolbarHidden(false, animated: false)
    }

    private func applyArrangement() {
        let axes: UIAxis = horizontalOnly ? .horizontal : [.horizontal, .vertical]
        if overlay {
            updateArrangement(.overlay.axes(axes), animated: true)
        } else {
            updateArrangement(.split.axes(axes), animated: true)
        }
        title = "\(overlay ? "Overlay" : "Split") · \(horizontalOnly ? "Horizontal" : "Both axes")"
    }

    private func makeContent(primary: Bool) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = primary ? .secondarySystemBackground : .tertiarySystemBackground
        let label = UILabel()
        label.text = primary
            ? "Primary\nResize or fold the display. Use the toolbar to change the arrangement or limit it to the horizontal axis."
            : "Secondary\nYour text stays here while this placement is hidden."
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        let textField = UITextField()
        textField.placeholder = "Try typing, then resize"
        textField.borderStyle = .roundedRect
        textField.accessibilityLabel = primary ? "Primary draft" : "Secondary draft"
        let push = Button(title: "Push detail") { [weak self] _ in
            guard let self else { return }
            let detail = UIViewController()
            detail.title = "Detail"
            detail.view.backgroundColor = .systemBackground
            let back = Button(title: "Return to arrangement") { [weak self] _ in
                guard let self else { return }
                navigator?.navigate(destination: .controller(self), strategy: .closeToExisting)
            }
            detail.view.embedIntoScroll(back)
            navigator?.navigate(destination: .controller(detail), strategy: .push())
        }
        controller.view.embedIntoScroll(label, textField, push)

        return controller
    }
}
#endif
