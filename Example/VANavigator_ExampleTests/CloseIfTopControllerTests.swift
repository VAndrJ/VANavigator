//
//  CloseIfTopControllerTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 07.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Testing
import UIKit
import VANavigator

// TODO: - Messages
@Suite(.serialized)
final class CloseIfTopControllerTests {
    let window: UIWindow? = UIWindow()

    @Test
    func `Dismisses matching top controller`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await preparePresented(navigator: navigator)
        let topIdentity = MockPushControllerNavigationIdentity()

        #expect(topIdentity.isEqual(to: window?.topController?.navigationIdentity))

        let expect = expectation(description: "navigation.closeIfTop")
        var result: Bool?
        navigator.navigate(
            destination: .identity(topIdentity),
            strategy: .closeIfTop(),
            completion: { _, isSuccess in
                result = isSuccess
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        let expectedIdentity = MockPopControllerNavigationIdentity()

        #expect((true) == (result))
        #expect(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    @Test
    func `Does not dismiss when controller is not on top`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await preparePresented(navigator: navigator)
        let topIdentity = MockPushControllerNavigationIdentity()
        let requestedIdentity = MockPopControllerNavigationIdentity()

        #expect(topIdentity.isEqual(to: window?.topController?.navigationIdentity))

        let expect = expectation(description: "navigation.closeIfTop")
        var result: Bool?
        navigator.navigate(
            destination: .identity(requestedIdentity),
            strategy: .closeIfTop(),
            completion: { _, isSuccess in
                result = isSuccess
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((false) == (result))
        #expect(topIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    @Test
    func `Does not dismiss target inside navigation stack`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await preparePresented(navigator: navigator)
        let topIdentity = MockPushControllerNavigationIdentity()

        #expect(topIdentity.isEqual(to: window?.topController?.navigationIdentity))

        let expect = expectation(description: "navigation.closeIfTop")
        var result: Bool?
        navigator.navigate(
            destination: .identity(topIdentity),
            strategy: .closeIfTop(tryToDismiss: false),
            completion: { _, isSuccess in
                result = isSuccess
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        let expectedIdentity = topIdentity

        #expect((false) == (result))
        #expect(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    @Test
    func `Closing without window reports failure`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let topIdentity = MockPushControllerNavigationIdentity()

        #expect((window?.topController) == nil)

        let expect = expectation(description: "navigation.closeIfTop")
        var result: Bool?
        navigator.navigate(
            destination: .identity(topIdentity),
            strategy: .closeIfTop(tryToDismiss: false),
            completion: { _, isSuccess in
                result = isSuccess
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((false) == (result))
    }

    @Test
    func `Pops matching top controller from navigation stack`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationStack(navigator: navigator)
        let topIdentity = MockPushControllerNavigationIdentity()
        let navigationController = window?.rootViewController as? UINavigationController

        #expect(topIdentity.isEqual(to: window?.topController?.navigationIdentity))
        #expect((3) == (navigationController?.viewControllers.count))

        let expect = expectation(description: "navigation.closeIfTop")
        var result: Bool?
        navigator.navigate(
            destination: .identity(topIdentity),
            strategy: .closeIfTop(),
            event: ResponderMockEvent(),
            completion: { _, isSuccess in
                result = isSuccess
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        let expectedIdentity = MockPopControllerNavigationIdentity()

        #expect((true) == (result))
        #expect(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        #expect((2) == (navigationController?.viewControllers.count))
        #expect(expectedIdentity.isEqual(to: navigationController?.topViewController?.navigationIdentity))
    }

    @Test
    func `Rejected UIKit pop reports failure`() async {
        let rootController = UIViewController()
        let topController = UIViewController()
        let navigationController = TopPopRejectingNavigationController()
        navigationController.setViewControllers([rootController, topController], animated: false)
        window?.rootViewController = navigationController
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let expect = expectation(description: "pop rejected")
        var result: Bool?

        navigator.navigate(
            destination: .controller(topController),
            strategy: .closeIfTop(tryToDismiss: false),
            animated: false,
            completion: { _, isSuccess in
                result = isSuccess
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((false) == (result))
        #expect(([rootController, topController]) == (navigationController.viewControllers))
        #expect((topController) === (navigationController.topViewController))
    }

    @Test
    func `Rejected UIKit dismissal reports failure`() async {
        let rootController = UIViewController()
        let presentedController = DismissRejectingViewController()
        window?.rootViewController = rootController
        window?.makeKeyAndVisible()
        defer { rootController.dismiss(animated: false) }

        let presentation = expectation(description: "dismiss rejection setup")
        rootController.present(presentedController, animated: false) {
            presentation.fulfill()
        }
        await fulfillment(of: [presentation], timeout: 10)

        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let completion = expectation(description: "dismiss rejected")
        var result: Bool?
        navigator.navigate(
            destination: .controller(presentedController),
            strategy: .closeIfTop(tryToPop: false),
            animated: false,
            completion: { _, isSuccess in
                result = isSuccess
                completion.fulfill()
            }
        )

        await fulfillment(of: [completion], timeout: 10)

        #expect(result == false)
        #expect(presentedController.dismissalAttempts == 1)
        #expect(rootController.presentedViewController === presentedController)
        #expect(window?.topController === presentedController)
    }

    @Test
    func `Does not pop controller below the top controller`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationStack(navigator: navigator)
        let topIdentity = MockPushControllerNavigationIdentity()
        let navigationController = window?.rootViewController as? UINavigationController

        #expect(topIdentity.isEqual(to: window?.topController?.navigationIdentity))
        #expect((3) == (navigationController?.viewControllers.count))

        let expect = expectation(description: "navigation.closeIfTop")
        navigator.navigate(
            destination: .identity(topIdentity),
            strategy: .closeIfTop(tryToPop: false),
            event: ResponderMockEvent(),
            completion: { _, _ in expect.fulfill() }
        )

        await fulfillment(of: [expect], timeout: 10)

        let expectedIdentity = topIdentity

        #expect(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        #expect((3) == (navigationController?.viewControllers.count))
        #expect(expectedIdentity.isEqual(to: navigationController?.topViewController?.navigationIdentity))
    }

    @Test
    func `Dismisses presented navigation when matching controller is its root`() async {
        let rootController = UIViewController()
        let presentedController = UIViewController()
        let navigationController = UINavigationController(rootViewController: presentedController)
        window?.rootViewController = rootController
        window?.makeKeyAndVisible()

        let presentExpect = expectation(description: "navigation.present")
        rootController.present(navigationController, animated: false) {
            presentExpect.fulfill()
        }
        await fulfillment(of: [presentExpect], timeout: 10)

        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let closeExpect = expectation(description: "navigation.closeIfTop")
        var result: Bool?
        navigator.navigate(
            destination: .controller(presentedController),
            strategy: .closeIfTop(),
            animated: false,
            completion: { _, isSuccess in
                result = isSuccess
                closeExpect.fulfill()
            }
        )

        await fulfillment(of: [closeExpect], timeout: 10)

        #expect((true) == (result))
        #expect((rootController.presentedViewController) == nil)
        #expect((rootController) === (window?.topController))
    }

    @Test
    func `Dismisses presented tab when matching controller is selected`() async {
        let presentedController = UIViewController()
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [presentedController]

        await assertDismissesPresentedContainer(
            tabBarController,
            matching: presentedController
        )
    }

    @Test
    func `Dismisses presented split when matching controller is visible`() async {
        let presentedController = UIViewController()
        let splitViewController = UISplitViewController(style: .doubleColumn)
        splitViewController.setViewController(UIViewController(), for: .primary)
        splitViewController.setViewController(presentedController, for: .secondary)

        await assertDismissesPresentedContainer(
            splitViewController,
            matching: presentedController
        )
    }

    @Test
    func `Dismisses presented custom container when matching controller is its child`() async {
        let presentedController = UIViewController()
        let customContainer = UIViewController()
        customContainer.addChild(presentedController)
        customContainer.view.addSubview(presentedController.view)
        presentedController.didMove(toParent: customContainer)

        await assertDismissesPresentedContainer(
            customContainer,
            matching: presentedController
        )
    }

    private func assertDismissesPresentedContainer(
        _ presentedContainer: UIViewController,
        matching presentedController: UIViewController
    ) async {
        let rootController = UIViewController()
        window?.rootViewController = rootController
        window?.makeKeyAndVisible()

        let presentExpect = expectation(description: "container.present")
        rootController.present(presentedContainer, animated: false) {
            presentExpect.fulfill()
        }
        await fulfillment(of: [presentExpect], timeout: 10)
        presentedContainer.view.layoutIfNeeded()

        #expect(window?.topController === presentedController)

        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let closeExpect = expectation(description: "container.closeIfTop")
        var result: Bool?
        navigator.navigate(
            destination: .controller(presentedController),
            strategy: .closeIfTop(),
            animated: false,
            completion: { _, isSuccess in
                result = isSuccess
                closeExpect.fulfill()
            }
        )
        await fulfillment(of: [closeExpect], timeout: 10)

        #expect(result == true)
        #expect(rootController.presentedViewController == nil)
        #expect(rootController === window?.topController)
    }

    func prepareNavigationStack(navigator: Navigator) async {
        let expect = expectation(description: "navigation.prepareNavigationStack")
        navigator.navigate(
            chain: [
                NavigationChainLink(
                    destination: .identity(
                        MockNavControllerNavigationIdentity(children: [
                            MockRootControllerNavigationIdentity()
                        ])
                    ),
                    strategy: .replaceWindowRoot(),
                    animated: false
                ),
                NavigationChainLink(
                    destination: .identity(MockPopControllerNavigationIdentity()),
                    strategy: .push(),
                    animated: false
                ),
                NavigationChainLink(
                    destination: .identity(MockPushControllerNavigationIdentity()),
                    strategy: .push(),
                    animated: false
                ),
            ],
            completion: { _, _ in expect.fulfill() }
        )

        await fulfillment(of: [expect], timeout: 10)
    }

    func preparePresented(navigator: Navigator) async {
        let expect = expectation(description: "navigation.prepareNavigationStack")
        navigator.navigate(
            chain: [
                NavigationChainLink(
                    destination: .identity(MockRootControllerNavigationIdentity()),
                    strategy: .replaceWindowRoot(),
                    animated: false
                ),
                NavigationChainLink(
                    destination: .identity(MockPopControllerNavigationIdentity()),
                    strategy: .present(),
                    animated: false
                ),
                NavigationChainLink(
                    destination: .identity(MockPushControllerNavigationIdentity()),
                    strategy: .present(),
                    animated: false
                ),
            ],
            completion: { _, _ in expect.fulfill() }
        )

        await fulfillment(of: [expect], timeout: 10)
    }
}

private final class TopPopRejectingNavigationController: UINavigationController {
    override func popViewController(animated: Bool) -> UIViewController? {
        return nil
    }
}

private final class DismissRejectingViewController: UIViewController {
    private(set) var dismissalAttempts = 0

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        dismissalAttempts += 1
        completion?()
    }
}
