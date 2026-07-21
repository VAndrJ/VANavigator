//
//  SplitControllerTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 17.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Testing
import UIKit
import VANavigator

// TODO: - Messages
@Suite(.serialized)
final class SplitControllerTests {
    let window: UIWindow?

    init() {
        guard let windowScene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            Issue.record("A window scene is required to run split-view tests")
            window = nil
            return
        }
        window = UIWindow(windowScene: windowScene)
    }

    @Test
    func `Pushes onto primary column`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationStack(navigator: navigator)
        let splitController = window?.rootViewController as? UISplitViewController
        let primaryIdentity = MockRootControllerNavigationIdentity()
        let secondaryIdentity = MockPopControllerNavigationIdentity()
        let newPrimaryIdentity = MockPushControllerNavigationIdentity()

        #expect((splitController) != nil)
        #expect(primaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
        #expect(secondaryIdentity.isEqual(to: splitController?.viewController(for: .secondary)?.navigationIdentity))

        let expect = expectation(description: "navigation")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(newPrimaryIdentity),
            strategy: .split(strategy: .primary(action: .push)),
            completion: {
                responder = $0
                result = $1
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((true) == (result))
        #expect(newPrimaryIdentity.isEqual(to: splitController?.columnNavigationController(for: .primary)?.topViewController?.navigationIdentity))
        #expect(newPrimaryIdentity.isEqual(to: responder?.navigationIdentity))
        let primaryControllers = splitController?.columnNavigationController(for: .primary)?.viewControllers
        #expect((2) == (primaryControllers?.filter { !($0 is UINavigationController) }.count))
        #expect(primaryIdentity.isEqual(to: primaryControllers?.first?.navigationIdentity))
        #expect(newPrimaryIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    @Test
    func `Existing primary controller fails without calling UIKit`() async {
        let existingController = UIViewController()
        let navigationController = SplitPushInvocationRecordingNavigationController()
        navigationController.setViewControllers([existingController], animated: false)
        let splitController = MockSplitViewController(style: .doubleColumn)
        splitController.setViewController(navigationController, for: .primary)
        splitController.setViewController(UIViewController(), for: .secondary)
        window?.rootViewController = splitController
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let expect = expectation(description: "navigation")
        var responder: UIViewController?
        var result: Bool?

        navigator.navigate(
            destination: .controller(existingController),
            strategy: .split(strategy: .primary(action: .push)),
            animated: false,
            completion: {
                responder = $0
                result = $1
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((false) == (result))
        #expect((responder) == nil)
        #expect((0) == (navigationController.pushInvocationCount))
        #expect(([existingController]) == (navigationController.viewControllers))
    }

    @Test
    func `Push fails when the split column changes navigation controller before completion`() async {
        guard let window else {
            Issue.record("Missing window")

            return
        }

        let originalRoot = UIViewController()
        let originalNavigationController = SplitColumnSwappingNavigationController(
            rootViewController: originalRoot
        )
        let replacementRoot = UIViewController()
        let replacementNavigationController = UINavigationController(rootViewController: replacementRoot)
        let splitController = SwitchingColumnNavigationSplitViewController(
            style: .doubleColumn,
            column: .primary,
            replacementController: replacementNavigationController
        )
        splitController.setViewController(originalNavigationController, for: .primary)
        splitController.setViewController(UIViewController(), for: .secondary)
        window.rootViewController = splitController
        window.makeKeyAndVisible()

        let destination = UIViewController()
        originalNavigationController.afterPush = { pushedController in
            guard pushedController === destination else { return }

            splitController.useReplacementController()
        }
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        var failures: [NavigationFailure.Reason] = []
        navigator.navigationFailureHandler = { failures.append($0.reason) }
        let completed = expectation(description: "split push after column replacement")
        var completedController: UIViewController?
        var isSuccess: Bool?

        navigator.navigate(
            destination: .controller(destination),
            strategy: .split(strategy: .primary(action: .push)),
            animated: false,
            completion: { controller, result in
                completedController = controller
                isSuccess = result
                completed.fulfill()
            }
        )

        await fulfillment(of: [completed], timeout: 10)

        #expect((false) == isSuccess)
        #expect(completedController == nil)
        #expect(failures == [.mutationRejected])
        #expect(originalNavigationController.topViewController === destination)
        #expect(splitController.columnNavigationController(for: .primary) === replacementNavigationController)
        #expect(splitController.columnNavigationController(for: .primary)?.topViewController === replacementRoot)
    }

    @Test
    func `Replace fails when the split column changes navigation controller before completion`() async {
        guard let window else {
            Issue.record("Missing window")

            return
        }

        let originalRoot = UIViewController()
        let originalNavigationController = SplitColumnSwappingNavigationController(
            rootViewController: originalRoot
        )
        let replacementRoot = UIViewController()
        let replacementNavigationController = UINavigationController(rootViewController: replacementRoot)
        let splitController = SwitchingColumnNavigationSplitViewController(
            style: .doubleColumn,
            column: .primary,
            replacementController: replacementNavigationController
        )
        splitController.setViewController(originalNavigationController, for: .primary)
        splitController.setViewController(UIViewController(), for: .secondary)
        window.rootViewController = splitController
        window.makeKeyAndVisible()

        let destination = UIViewController()
        originalNavigationController.afterSetViewControllers = { viewControllers in
            guard viewControllers.count == 1, viewControllers.first === destination else { return }

            splitController.useReplacementController()
        }
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        var failures: [NavigationFailure.Reason] = []
        navigator.navigationFailureHandler = { failures.append($0.reason) }
        let completed = expectation(description: "split replace after column replacement")
        var completedController: UIViewController?
        var isSuccess: Bool?

        navigator.navigate(
            destination: .controller(destination),
            strategy: .split(strategy: .primary(action: .replace)),
            animated: false,
            completion: { controller, result in
                completedController = controller
                isSuccess = result
                completed.fulfill()
            }
        )

        await fulfillment(of: [completed], timeout: 10)

        #expect((false) == isSuccess)
        #expect(completedController == nil)
        #expect(failures == [.mutationRejected])
        #expect(originalNavigationController.topViewController === destination)
        #expect(splitController.columnNavigationController(for: .primary) === replacementNavigationController)
        #expect(splitController.columnNavigationController(for: .primary)?.topViewController === replacementRoot)
    }

    @Test
    func `Pop fails when the split column changes navigation controller before completion`() async {
        guard let window else {
            Issue.record("Missing window")

            return
        }

        let destination = UIViewController()
        let originalNavigationController = SplitColumnSwappingNavigationController(
            rootViewController: destination
        )
        originalNavigationController.pushViewController(UIViewController(), animated: false)
        let replacementRoot = UIViewController()
        let replacementNavigationController = UINavigationController(rootViewController: replacementRoot)
        let splitController = SwitchingColumnNavigationSplitViewController(
            style: .doubleColumn,
            column: .primary,
            replacementController: replacementNavigationController
        )
        splitController.setViewController(originalNavigationController, for: .primary)
        splitController.setViewController(UIViewController(), for: .secondary)
        window.rootViewController = splitController
        window.makeKeyAndVisible()

        originalNavigationController.afterPopToViewController = { poppedToController in
            guard poppedToController === destination else { return }

            splitController.useReplacementController()
        }
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        var failures: [NavigationFailure.Reason] = []
        navigator.navigationFailureHandler = { failures.append($0.reason) }
        let completed = expectation(description: "split pop after column replacement")
        var completedController: UIViewController?
        var isSuccess: Bool?

        navigator.navigate(
            destination: .controller(destination),
            strategy: .split(strategy: .primary(action: .pop)),
            animated: false,
            completion: { controller, result in
                completedController = controller
                isSuccess = result
                completed.fulfill()
            }
        )

        await fulfillment(of: [completed], timeout: 10)

        #expect((false) == isSuccess)
        #expect(completedController == nil)
        #expect(failures == [.mutationRejected])
        #expect(originalNavigationController.topViewController === destination)
        #expect(splitController.columnNavigationController(for: .primary) === replacementNavigationController)
        #expect(splitController.columnNavigationController(for: .primary)?.topViewController === replacementRoot)
    }

    @Test
    func `Primary replacement rejects navigation controller destination`() async {
        let existingController = UIViewController()
        let navigationController = UINavigationController(rootViewController: existingController)
        let splitController = MockSplitViewController(style: .doubleColumn)
        splitController.setViewController(navigationController, for: .primary)
        splitController.setViewController(UIViewController(), for: .secondary)
        window?.rootViewController = splitController
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let nestedNavigationController = UINavigationController(rootViewController: UIViewController())
        let expect = expectation(description: "split replace rejected")
        var responder: UIViewController?
        var result: Bool?

        navigator.navigate(
            destination: .controller(nestedNavigationController),
            strategy: .split(strategy: .primary(action: .replace)),
            animated: false,
            completion: {
                responder = $0
                result = $1
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((false) == (result))
        #expect((responder) == nil)
        #expect(([existingController]) == (navigationController.viewControllers))
        #expect((nestedNavigationController.parent) == nil)
    }

    @Test
    func `Pops to controller in primary column`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationStack(navigator: navigator)
        let splitController = window?.rootViewController as? UISplitViewController
        let primaryIdentity = MockRootControllerNavigationIdentity()
        let secondaryIdentity = MockPopControllerNavigationIdentity()
        let newPrimaryIdentity = MockPushControllerNavigationIdentity()

        #expect((splitController) != nil)
        #expect(primaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
        #expect(secondaryIdentity.isEqual(to: splitController?.viewController(for: .secondary)?.navigationIdentity))

        let expect = expectation(description: "navigation")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(newPrimaryIdentity),
            strategy: .split(strategy: .primary(action: .push)),
            completion: {
                responder = $0
                result = $1
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((true) == (result))
        #expect(newPrimaryIdentity.isEqual(to: splitController?.columnNavigationController(for: .primary)?.topViewController?.navigationIdentity))
        #expect(newPrimaryIdentity.isEqual(to: responder?.navigationIdentity))
        let primaryControllers = splitController?.columnNavigationController(for: .primary)?.viewControllers
        #expect((2) == (primaryControllers?.filter { !($0 is UINavigationController) }.count))
        #expect(primaryIdentity.isEqual(to: primaryControllers?.first?.navigationIdentity))

        let expect1 = expectation(description: "navigation1")
        navigator.navigate(
            destination: .identity(primaryIdentity),
            strategy: .split(strategy: .primary(action: .pop)),
            completion: {
                responder = $0
                result = $1
                expect1.fulfill()
            }
        )

        await fulfillment(of: [expect1], timeout: 10)

        #expect((true) == (result))
        #expect(primaryIdentity.isEqual(to: splitController?.columnNavigationController(for: .primary)?.topViewController?.navigationIdentity))
        let primaryControllers1 = splitController?.columnNavigationController(for: .primary)?.viewControllers
        #expect((1) == (primaryControllers1?.filter { !($0 is UINavigationController) }.count))
        #expect(primaryIdentity.isEqual(to: primaryControllers1?.first?.navigationIdentity))
        #expect(primaryIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    @Test
    func `Primary pop reports failure`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationStack(navigator: navigator)
        let splitController = window?.rootViewController as? UISplitViewController
        let primaryIdentity = MockRootControllerNavigationIdentity()
        let secondaryIdentity = MockPopControllerNavigationIdentity()
        let newPrimaryIdentity = MockPushControllerNavigationIdentity()
        let failureIdentity = MockNavControllerNavigationIdentity(children: [])

        #expect((splitController) != nil)
        #expect(primaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
        #expect(secondaryIdentity.isEqual(to: splitController?.viewController(for: .secondary)?.navigationIdentity))

        let expect = expectation(description: "navigation")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(newPrimaryIdentity),
            strategy: .split(strategy: .primary(action: .push)),
            completion: {
                responder = $0
                result = $1
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((true) == (result))
        #expect(newPrimaryIdentity.isEqual(to: splitController?.columnNavigationController(for: .primary)?.topViewController?.navigationIdentity))
        #expect(newPrimaryIdentity.isEqual(to: responder?.navigationIdentity))
        let primaryControllers = splitController?.columnNavigationController(for: .primary)?.viewControllers
        #expect((2) == (primaryControllers?.filter { !($0 is UINavigationController) }.count))
        #expect(primaryIdentity.isEqual(to: primaryControllers?.first?.navigationIdentity))

        let expect1 = expectation(description: "navigation1")
        navigator.navigate(
            destination: .identity(failureIdentity),
            strategy: .split(strategy: .primary(action: .pop)),
            completion: {
                responder = $0
                result = $1
                expect1.fulfill()
            }
        )

        await fulfillment(of: [expect1], timeout: 10)

        #expect((false) == (result))
        #expect(newPrimaryIdentity.isEqual(to: splitController?.columnNavigationController(for: .primary)?.topViewController?.navigationIdentity))
        let primaryControllers1 = splitController?.columnNavigationController(for: .primary)?.viewControllers
        #expect((2) == (primaryControllers1?.filter { !($0 is UINavigationController) }.count))
        #expect(primaryIdentity.isEqual(to: primaryControllers1?.first?.navigationIdentity))
        #expect(newPrimaryIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    @Test
    func `Primary pop failure uses fallback`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationStack(navigator: navigator)
        let splitController = window?.rootViewController as? UISplitViewController
        let primaryIdentity = MockRootControllerNavigationIdentity()
        let secondaryIdentity = MockPopControllerNavigationIdentity()
        let newPrimaryIdentity = MockPushControllerNavigationIdentity()
        let failureIdentity = MockNavControllerNavigationIdentity(children: [])

        #expect((splitController) != nil)
        #expect(primaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
        #expect(secondaryIdentity.isEqual(to: splitController?.viewController(for: .secondary)?.navigationIdentity))

        let expect = expectation(description: "navigation")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(newPrimaryIdentity),
            strategy: .split(strategy: .primary(action: .push)),
            completion: {
                responder = $0
                result = $1
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((true) == (result))
        #expect(newPrimaryIdentity.isEqual(to: splitController?.columnNavigationController(for: .primary)?.topViewController?.navigationIdentity))
        #expect(newPrimaryIdentity.isEqual(to: responder?.navigationIdentity))
        let primaryControllers = splitController?.columnNavigationController(for: .primary)?.viewControllers
        #expect((2) == (primaryControllers?.filter { !($0 is UINavigationController) }.count))
        #expect(primaryIdentity.isEqual(to: primaryControllers?.first?.navigationIdentity))

        let expect1 = expectation(description: "navigation1")
        navigator.navigate(
            destination: .identity(failureIdentity),
            strategy: .split(strategy: .primary(action: .pop)),
            fallback: NavigationChainLink(
                destination: .identity(primaryIdentity),
                strategy: .split(strategy: .primary(action: .pop)),
                animated: true
            ),
            completion: {
                responder = $0
                result = $1
                expect1.fulfill()
            }
        )

        await fulfillment(of: [expect1], timeout: 10)

        #expect((true) == (result))
        #expect(primaryIdentity.isEqual(to: splitController?.columnNavigationController(for: .primary)?.topViewController?.navigationIdentity))
        let primaryControllers1 = splitController?.columnNavigationController(for: .primary)?.viewControllers
        #expect((1) == (primaryControllers1?.filter { !($0 is UINavigationController) }.count))
        #expect(primaryIdentity.isEqual(to: primaryControllers1?.first?.navigationIdentity))
        #expect(primaryIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    @Test
    func `Replaces primary column`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationStack(navigator: navigator)
        let splitController = window?.rootViewController as? UISplitViewController
        let primaryIdentity = MockRootControllerNavigationIdentity()
        let secondaryIdentity = MockPopControllerNavigationIdentity()
        let newPrimaryIdentity = MockPushControllerNavigationIdentity()

        #expect((splitController) != nil)
        #expect(primaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
        #expect(secondaryIdentity.isEqual(to: splitController?.viewController(for: .secondary)?.navigationIdentity))

        let expect = expectation(description: "navigation")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(newPrimaryIdentity),
            strategy: .split(strategy: .primary(action: .replace)),
            completion: {
                responder = $0
                result = $1
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((true) == (result))
        #expect(newPrimaryIdentity.isEqual(to: splitController?.columnNavigationController(for: .primary)?.topViewController?.navigationIdentity))
        #expect(newPrimaryIdentity.isEqual(to: responder?.navigationIdentity))
        if splitController?.isSingleNavigation == false {
            #expect(secondaryIdentity.isEqual(to: splitController?.viewController(for: .secondary)?.navigationIdentity))
        }
        #expect(newPrimaryIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    @Test
    func `Pushes onto secondary column`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationStack(navigator: navigator)
        let splitController = window?.rootViewController as? UISplitViewController
        let primaryIdentity = MockRootControllerNavigationIdentity()
        let secondaryIdentity = MockPopControllerNavigationIdentity()
        let newPrimaryIdentity = MockPushControllerNavigationIdentity()

        #expect((splitController) != nil)
        #expect(primaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
        #expect(secondaryIdentity.isEqual(to: splitController?.viewController(for: .secondary)?.navigationIdentity))

        let expect = expectation(description: "navigation")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(newPrimaryIdentity),
            strategy: .split(strategy: .secondary(action: .push)),
            completion: {
                responder = $0
                result = $1
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((true) == (result))
        #expect(newPrimaryIdentity.isEqual(to: responder?.navigationIdentity))
        let secondaryControllers = splitController?.columnNavigationController(for: .secondary)?.viewControllers
        #expect((2) == (secondaryControllers?.filter { !($0 is UINavigationController) }.count))
        #expect(secondaryIdentity.isEqual(to: secondaryControllers?.first?.navigationIdentity))
        #expect(newPrimaryIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    @Test
    func `Pops to controller in secondary column`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationStack(navigator: navigator)
        let splitController = window?.rootViewController as? UISplitViewController
        let primaryIdentity = MockRootControllerNavigationIdentity()
        let secondaryIdentity = MockPopControllerNavigationIdentity()
        let newPrimaryIdentity = MockPushControllerNavigationIdentity()

        #expect((splitController) != nil)
        #expect(primaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
        #expect(secondaryIdentity.isEqual(to: splitController?.viewController(for: .secondary)?.navigationIdentity))

        let expect = expectation(description: "navigation")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(newPrimaryIdentity),
            strategy: .split(strategy: .secondary(action: .push)),
            completion: {
                responder = $0
                result = $1
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((true) == (result))
        #expect(newPrimaryIdentity.isEqual(to: responder?.navigationIdentity))
        let secondaryControllers = splitController?.columnNavigationController(for: .secondary)?.viewControllers
        #expect((2) == (secondaryControllers?.filter { !($0 is UINavigationController) }.count))
        #expect(secondaryIdentity.isEqual(to: secondaryControllers?.first?.navigationIdentity))

        let expect1 = expectation(description: "navigation1")
        navigator.navigate(
            destination: .identity(secondaryIdentity),
            strategy: .split(strategy: .secondary(action: .pop)),
            completion: {
                responder = $0
                result = $1
                expect1.fulfill()
            }
        )

        await fulfillment(of: [expect1], timeout: 10)

        #expect((true) == (result))
        #expect(secondaryIdentity.isEqual(to: splitController?.columnNavigationController(for: .secondary)?.topViewController?.navigationIdentity))
        let secondaryControllers1 = splitController?.columnNavigationController(for: .secondary)?.viewControllers
        #expect((1) == (secondaryControllers1?.filter { !($0 is UINavigationController) }.count))
        #expect(secondaryIdentity.isEqual(to: secondaryControllers1?.first?.navigationIdentity))
        #expect(secondaryIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    @Test
    func `Secondary pop reports failure`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationStack(navigator: navigator)
        let splitController = window?.rootViewController as? UISplitViewController
        let primaryIdentity = MockRootControllerNavigationIdentity()
        let secondaryIdentity = MockPopControllerNavigationIdentity()
        let newPrimaryIdentity = MockPushControllerNavigationIdentity()
        let failureIdentity = MockNavControllerNavigationIdentity(children: [])

        #expect((splitController) != nil)
        #expect(primaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
        #expect(secondaryIdentity.isEqual(to: splitController?.viewController(for: .secondary)?.navigationIdentity))

        let expect = expectation(description: "navigation")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(newPrimaryIdentity),
            strategy: .split(strategy: .secondary(action: .push)),
            completion: {
                responder = $0
                result = $1
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((true) == (result))
        #expect(newPrimaryIdentity.isEqual(to: responder?.navigationIdentity))
        let secondaryControllers = splitController?.columnNavigationController(for: .secondary)?.viewControllers
        #expect((2) == (secondaryControllers?.filter { !($0 is UINavigationController) }.count))
        #expect(secondaryIdentity.isEqual(to: secondaryControllers?.first?.navigationIdentity))

        let expect1 = expectation(description: "navigation1")
        navigator.navigate(
            destination: .identity(failureIdentity),
            strategy: .split(strategy: .secondary(action: .pop)),
            completion: {
                responder = $0
                result = $1
                expect1.fulfill()
            }
        )

        await fulfillment(of: [expect1], timeout: 10)

        #expect((false) == (result))
        let secondaryControllers1 = splitController?.columnNavigationController(for: .secondary)?.viewControllers
        #expect((2) == (secondaryControllers1?.filter { !($0 is UINavigationController) }.count))
        #expect(secondaryIdentity.isEqual(to: secondaryControllers1?.first?.navigationIdentity))
        #expect(newPrimaryIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    @Test
    func `Secondary pop failure uses fallback`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationStack(navigator: navigator)
        let splitController = window?.rootViewController as? UISplitViewController
        let primaryIdentity = MockRootControllerNavigationIdentity()
        let secondaryIdentity = MockPopControllerNavigationIdentity()
        let newPrimaryIdentity = MockPushControllerNavigationIdentity()
        let failureIdentity = MockNavControllerNavigationIdentity(children: [])

        #expect((splitController) != nil)
        #expect(primaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
        #expect(secondaryIdentity.isEqual(to: splitController?.viewController(for: .secondary)?.navigationIdentity))

        let expect = expectation(description: "navigation")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(newPrimaryIdentity),
            strategy: .split(strategy: .secondary(action: .push)),
            completion: {
                responder = $0
                result = $1
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((true) == (result))
        #expect(newPrimaryIdentity.isEqual(to: responder?.navigationIdentity))
        let secondaryControllers = splitController?.columnNavigationController(for: .secondary)?.viewControllers
        #expect((2) == (secondaryControllers?.filter { !($0 is UINavigationController) }.count))
        #expect(secondaryIdentity.isEqual(to: secondaryControllers?.first?.navigationIdentity))

        let expect1 = expectation(description: "navigation1")
        navigator.navigate(
            destination: .identity(failureIdentity),
            strategy: .split(strategy: .secondary(action: .pop)),
            fallback: NavigationChainLink(
                destination: .identity(secondaryIdentity),
                strategy: .split(strategy: .secondary(action: .pop)),
                animated: true
            ),
            completion: {
                responder = $0
                result = $1
                expect1.fulfill()
            }
        )

        await fulfillment(of: [expect1], timeout: 10)

        #expect((true) == (result))
        let secondaryControllers1 = splitController?.columnNavigationController(for: .secondary)?.viewControllers
        #expect((1) == (secondaryControllers1?.filter { !($0 is UINavigationController) }.count))
        #expect(secondaryIdentity.isEqual(to: secondaryControllers1?.first?.navigationIdentity))
        #expect(secondaryIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    @Test
    func `Replaces secondary column`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationStack(navigator: navigator)
        let splitController = window?.rootViewController as? UISplitViewController
        let primaryIdentity = MockRootControllerNavigationIdentity()
        let secondaryIdentity = MockPopControllerNavigationIdentity()
        let newPrimaryIdentity = MockPushControllerNavigationIdentity()

        #expect((splitController) != nil)
        #expect(primaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
        #expect(secondaryIdentity.isEqual(to: splitController?.viewController(for: .secondary)?.navigationIdentity))

        let expect = expectation(description: "navigation")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(newPrimaryIdentity),
            strategy: .split(strategy: .secondary(action: .replace)),
            completion: {
                responder = $0
                result = $1
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((true) == (result))
        #expect(newPrimaryIdentity.isEqual(to: splitController?.columnNavigationController(for: .secondary)?.topViewController?.navigationIdentity))
        #expect(newPrimaryIdentity.isEqual(to: responder?.navigationIdentity))
        #expect(newPrimaryIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    @Test
    func `Missing primary column navigation uses replacement fallback`() async {
        await assertSplitColumnNavigationFallback(
            strategy: .primary(action: .replace),
            failedColumn: .primary
        )
    }

    @Test
    func `Missing primary column navigation uses push fallback`() async {
        await assertSplitColumnNavigationFallback(
            strategy: .primary(action: .push),
            failedColumn: .primary
        )
    }

    @Test
    func `Missing secondary column navigation uses replacement fallback`() async {
        await assertSplitColumnNavigationFallback(
            strategy: .secondary(action: .replace),
            failedColumn: .secondary
        )
    }

    @Test
    func `Missing secondary column navigation uses push fallback`() async {
        await assertSplitColumnNavigationFallback(
            strategy: .secondary(action: .push),
            failedColumn: .secondary
        )
    }

    func assertSplitColumnNavigationFallback(
        strategy: SplitStrategy,
        failedColumn: UISplitViewController.Column,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStackWithMissingColumnNavigation(failedColumn: failedColumn)
        let splitController = window?.rootViewController as? MissingColumnNavigationSplitViewController
        let newIdentity = MockPushControllerNavigationIdentity()

        #expect(
            (splitController) != nil,
            sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
        )

        let expect = expectation(description: "navigation")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(newIdentity),
            strategy: .split(strategy: strategy),
            animated: false,
            fallback: NavigationChainLink(
                destination: .identity(newIdentity),
                strategy: .replaceWindowRoot(),
                animated: false
            ),
            completion: {
                responder = $0
                result = $1
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect(
            (true) == (result),
            sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
        )
        #expect(
            newIdentity.isEqual(to: responder?.navigationIdentity),
            sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
        )
        #expect(
            newIdentity.isEqual(to: window?.rootViewController?.navigationIdentity),
            sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
        )
    }

    func prepareNavigationStack(navigator: Navigator) async {
        let expect = expectation(description: "navigation.prepareNavigationStack")
        navigator.navigate(
            destination: .identity(
                MockSplitControllerNavigationIdentity(
                    primary: MockRootControllerNavigationIdentity(),
                    secondary: MockPopControllerNavigationIdentity()
                )
            ),
            strategy: .replaceWindowRoot(),
            animated: false,
            completion: { _, _ in expect.fulfill() }
        )

        await fulfillment(of: [expect], timeout: 10)
        window?.rootViewController?.loadViewIfNeeded()
        window?.rootViewController?.view.layoutIfNeeded()
    }

    func prepareNavigationStackWithMissingColumnNavigation(failedColumn: UISplitViewController.Column) {
        let splitController = MissingColumnNavigationSplitViewController(failedColumn: failedColumn)
        let primaryIdentity = MockRootControllerNavigationIdentity()
        let secondaryIdentity = MockPopControllerNavigationIdentity()
        let primary = UIViewController()
        let secondary = UIViewController()
        primary.navigationIdentity = primaryIdentity
        secondary.navigationIdentity = secondaryIdentity
        splitController.setViewController(primary, for: .primary)
        splitController.setViewController(secondary, for: .secondary)
        splitController.navigationIdentity = MockSplitControllerNavigationIdentity(
            primary: primaryIdentity,
            secondary: secondaryIdentity
        )
        window?.rootViewController = splitController
        window?.makeKeyAndVisible()
    }

    @Test
    func `Missing split controller uses primary push fallback`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationStackWithoutSplit(navigator: navigator)
        let splitController = window?.rootViewController as? UISplitViewController
        let primaryIdentity = MockRootControllerNavigationIdentity()
        let newPrimaryIdentity = MockPushControllerNavigationIdentity()

        #expect((splitController) == nil)
        #expect(primaryIdentity.isEqual(to: window?.topController?.navigationIdentity))

        let expect = expectation(description: "navigation")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(newPrimaryIdentity),
            strategy: .split(strategy: .primary(action: .push)),
            fallback: NavigationChainLink(
                destination: .identity(newPrimaryIdentity),
                strategy: .present(),
                animated: true
            ),
            completion: {
                responder = $0
                result = $1
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((true) == (result))
        #expect(newPrimaryIdentity.isEqual(to: window?.topController?.navigationIdentity))
        #expect(newPrimaryIdentity.isEqual(to: responder?.navigationIdentity))
    }

    func prepareNavigationStackWithoutSplit(navigator: Navigator) async {
        let expect = expectation(description: "navigation.prepareNavigationStack")
        navigator.navigate(
            destination: .identity(MockRootControllerNavigationIdentity()),
            strategy: .replaceWindowRoot(),
            animated: false,
            completion: { _, _ in expect.fulfill() }
        )

        await fulfillment(of: [expect], timeout: 10)
    }
}

private final class MissingColumnNavigationSplitViewController: MockSplitViewController {
    private let failedColumn: UISplitViewController.Column

    init(failedColumn: UISplitViewController.Column) {
        self.failedColumn = failedColumn

        super.init(style: .doubleColumn)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewController(for column: UISplitViewController.Column) -> UIViewController? {
        column == failedColumn ? nil : super.viewController(for: column)
    }
}

private final class SplitPushInvocationRecordingNavigationController: UINavigationController {
    private(set) var pushInvocationCount = 0

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        pushInvocationCount += 1
        super.pushViewController(viewController, animated: animated)
    }
}

private final class SplitColumnSwappingNavigationController: UINavigationController {
    var afterPush: ((UIViewController) -> Void)?
    var afterSetViewControllers: (([UIViewController]) -> Void)?
    var afterPopToViewController: ((UIViewController) -> Void)?

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        super.pushViewController(viewController, animated: animated)

        afterPush?(viewController)
    }

    override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
        super.setViewControllers(viewControllers, animated: animated)

        afterSetViewControllers?(viewControllers)
    }

    override func popToViewController(
        _ viewController: UIViewController,
        animated: Bool
    ) -> [UIViewController]? {
        let poppedControllers = super.popToViewController(viewController, animated: animated)
        afterPopToViewController?(viewController)

        return poppedControllers
    }
}

private final class SwitchingColumnNavigationSplitViewController: MockSplitViewController {
    private let switchedColumn: UISplitViewController.Column
    private let replacementController: UIViewController
    private var isUsingReplacementController = false

    init(
        style: UISplitViewController.Style,
        column: UISplitViewController.Column,
        replacementController: UIViewController
    ) {
        self.switchedColumn = column
        self.replacementController = replacementController

        super.init(style: style)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func useReplacementController() {
        isUsingReplacementController = true
    }

    override func viewController(for column: UISplitViewController.Column) -> UIViewController? {
        guard isUsingReplacementController, column == switchedColumn else {
            return super.viewController(for: column)
        }

        return replacementController
    }
}
