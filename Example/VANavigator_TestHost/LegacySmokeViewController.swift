//
//  LegacySmokeViewController.swift
//  VANavigator_TestHost
//

import UIKit
import VANavigator

/// A dependency-free manual smoke test for the library's iOS 15 deployment target.
///
/// The main example uses an iOS 17 dependency, so this host intentionally exercises the
/// package directly without importing any example-only packages.
final class LegacySmokeViewController: UIViewController {
    private let statusLabel = UILabel()
    private let runButton = UIButton(type: .system)
    private var navigator: Navigator?
    private var didRunAutomatically = false
    private var completedSmokeSteps = 0
    private var didFinishSmokeTest = false
    private var smokeTimeoutWorkItem: DispatchWorkItem?

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "VANavigator iOS 15 Smoke Test"
        view.backgroundColor = .systemBackground

        statusLabel.accessibilityIdentifier = "legacy-smoke-status"
        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.numberOfLines = 0
        statusLabel.text = "Ready"
        statusLabel.textAlignment = .center

        runButton.accessibilityIdentifier = "legacy-smoke-run"
        runButton.configuration = .filled()
        runButton.configuration?.title = "Run navigation smoke test"
        runButton.addTarget(self, action: #selector(runSmokeTest), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [statusLabel, runButton])
        stack.axis = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !didRunAutomatically,
            ProcessInfo.processInfo.arguments.contains("--run-smoke-test")
        else {
            return
        }

        didRunAutomatically = true
        runSmokeTest()
    }

    @objc private func runSmokeTest() {
        guard let window = view.window, let navigationController else {
            finish(with: "FAIL: host window or navigation controller is unavailable", succeeded: false)

            return
        }

        runButton.isEnabled = false
        statusLabel.text = "Running…"
        completedSmokeSteps = 0
        didFinishSmokeTest = false

        let navigator = Navigator(
            window: window,
            screenFactory: LegacySmokeScreenFactory()
        )
        navigator.navigationFailureHandler = { [weak self] failure in
            self?.finish(
                with: "FAIL: \(failure.reason.rawValue)",
                succeeded: false
            )
        }
        self.navigator = navigator

        let pushedController = UIViewController()
        pushedController.view.backgroundColor = .systemBackground
        pushedController.title = "Pushed"
        let presentedController = UIViewController()
        presentedController.view.backgroundColor = .systemBackground
        presentedController.title = "Presented"

        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            self?.finish(with: "FAIL: timed out waiting for the navigation queue", succeeded: false)
        }
        smokeTimeoutWorkItem = timeoutWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeoutWorkItem)

        navigator.navigate(
            destination: .controller(pushedController),
            strategy: .push(),
            animated: true,
            completion: { [weak self] controller, didPush in
                self?.recordSmokeStep(
                    0,
                    name: "push",
                    succeeded: didPush
                        && controller === pushedController
                        && navigationController.topViewController === pushedController
                )
            }
        )
        navigator.navigate(
            destination: .controller(presentedController),
            strategy: .present(),
            animated: true,
            completion: { [weak self] controller, didPresent in
                self?.recordSmokeStep(
                    1,
                    name: "presentation",
                    succeeded: didPresent
                        && controller === presentedController
                        && presentedController.presentingViewController != nil
                )
            }
        )
        navigator.navigate(
            destination: .controller(presentedController),
            strategy: .closeIfTop(tryToPop: false),
            animated: true,
            completion: { [weak self] _, didClose in
                self?.recordSmokeStep(
                    2,
                    name: "dismissal",
                    succeeded: didClose && presentedController.presentingViewController == nil
                )
            }
        )
        navigator.navigate(
            destination: .controller(pushedController),
            strategy: .closeIfTop(tryToDismiss: false),
            animated: true,
            completion: { [weak self] _, didClose in
                guard let self else { return }

                recordSmokeStep(
                    3,
                    name: "pop",
                    succeeded: didClose && navigationController.topViewController === self
                )
            }
        )
    }

    private func recordSmokeStep(_ step: Int, name: String, succeeded: Bool) {
        guard !didFinishSmokeTest else { return }
        guard succeeded else {
            finish(with: "FAIL: \(name)", succeeded: false)

            return
        }
        guard completedSmokeSteps == step else {
            finish(with: "FAIL: navigation callbacks completed out of order", succeeded: false)

            return
        }

        completedSmokeSteps += 1
        if completedSmokeSteps == 4 {
            finish(with: "PASS: push, present, dismiss, pop, and queue serialization", succeeded: true)
        }
    }

    private func finish(with message: String, succeeded: Bool) {
        guard !didFinishSmokeTest else { return }

        didFinishSmokeTest = true
        smokeTimeoutWorkItem?.cancel()
        smokeTimeoutWorkItem = nil
        statusLabel.text = message
        statusLabel.textColor = succeeded ? .systemGreen : .systemRed
        runButton.isEnabled = true
        navigator = nil
        print("VANAVIGATOR_LEGACY_SMOKE: \(message)")
    }
}

private struct LegacySmokeScreenFactory: NavigatorScreenFactory {
    func assembleScreen(identity: any NavigationIdentity, navigator: Navigator) -> UIViewController {
        UIViewController()
    }
}
