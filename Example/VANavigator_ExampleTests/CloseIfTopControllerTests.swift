//
//  CloseIfTopControllerTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 07.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit
import VANavigator
import XCTest

// TODO: - Messages
@MainActor
class CloseIfTopControllerTests: XCTestCase {
    var window: UIWindow?

    override func setUp() async throws {
        window = UIWindow()
    }

    override func tearDown() async throws {
        window = nil
    }

    func test_controllerDismiss() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        preparePresented(navigator: navigator)
        let topIdentity = MockPushControllerNavigationIdentity()

        XCTAssertTrue(topIdentity.isEqual(to: window?.topController?.navigationIdentity))

        let expect = expectation(description: "navigation.closeIfTop")
        var result: Bool?
        navigator.navigate(
            destination: .identity(topIdentity),
            strategy: .closeIfTop(),
            completion: { _, isSuccess in
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        let expectedIdentity = MockPopControllerNavigationIdentity()

        XCTAssertEqual(true, result)
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    func test_controllerDismiss_notTop() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        preparePresented(navigator: navigator)
        let topIdentity = MockPushControllerNavigationIdentity()
        let requestedIdentity = MockPopControllerNavigationIdentity()

        XCTAssertTrue(topIdentity.isEqual(to: window?.topController?.navigationIdentity))

        let expect = expectation(description: "navigation.closeIfTop")
        var result: Bool?
        navigator.navigate(
            destination: .identity(requestedIdentity),
            strategy: .closeIfTop(),
            completion: { _, isSuccess in
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(false, result)
        XCTAssertTrue(topIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    func test_controllerPop_notDismissed() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        preparePresented(navigator: navigator)
        let topIdentity = MockPushControllerNavigationIdentity()

        XCTAssertTrue(topIdentity.isEqual(to: window?.topController?.navigationIdentity))

        let expect = expectation(description: "navigation.closeIfTop")
        var result: Bool?
        navigator.navigate(
            destination: .identity(topIdentity),
            strategy: .closeIfTop(tryToDismiss: false),
            completion: { _, isSuccess in
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        let expectedIdentity = topIdentity

        XCTAssertEqual(false, result)
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    func test_controllerClose_withoutWindow() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let topIdentity = MockPushControllerNavigationIdentity()

        XCTAssertNil(window?.topController)

        let expect = expectation(description: "navigation.closeIfTop")
        var result: Bool?
        navigator.navigate(
            destination: .identity(topIdentity),
            strategy: .closeIfTop(tryToDismiss: false),
            completion: { _, isSuccess in
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(false, result)
    }

    func test_controllerPop() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStack(navigator: navigator)
        let topIdentity = MockPushControllerNavigationIdentity()
        let navigationController = window?.rootViewController as? UINavigationController

        XCTAssertTrue(topIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertEqual(3, navigationController?.viewControllers.count)

        let expect = expectation(description: "navigation.closeIfTop")
        var result: Bool?
        navigator.navigate(
            destination: .identity(topIdentity),
            strategy: .closeIfTop(),
            event: ResponderMockEvent(),
            completion: { _, isSuccess in
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        let expectedIdentity = MockPopControllerNavigationIdentity()

        XCTAssertEqual(true, result)
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertEqual(2, navigationController?.viewControllers.count)
        XCTAssertTrue(expectedIdentity.isEqual(to: navigationController?.topViewController?.navigationIdentity))
    }

    func test_controllerPop_reportsFailureWhenUIKitRejectsPop() {
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

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(false, result)
        XCTAssertEqual([rootController, topController], navigationController.viewControllers)
        XCTAssertIdentical(topController, navigationController.topViewController)
    }

    func test_controllerPop_notPopped() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStack(navigator: navigator)
        let topIdentity = MockPushControllerNavigationIdentity()
        let navigationController = window?.rootViewController as? UINavigationController

        XCTAssertTrue(topIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertEqual(3, navigationController?.viewControllers.count)

        let expect = expectation(description: "navigation.closeIfTop")
        navigator.navigate(
            destination: .identity(topIdentity),
            strategy: .closeIfTop(tryToPop: false),
            event: ResponderMockEvent(),
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)

        let expectedIdentity = topIdentity

        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertEqual(3, navigationController?.viewControllers.count)
        XCTAssertTrue(expectedIdentity.isEqual(to: navigationController?.topViewController?.navigationIdentity))
    }

    func test_controllerDismissesPresentedNavigationControllerWhenMatchingControllerIsItsRoot() {
        let rootController = UIViewController()
        let presentedController = UIViewController()
        let navigationController = UINavigationController(rootViewController: presentedController)
        window?.rootViewController = rootController
        window?.makeKeyAndVisible()

        let presentExpect = expectation(description: "navigation.present")
        rootController.present(navigationController, animated: false) {
            presentExpect.fulfill()
        }
        wait(for: [presentExpect], timeout: 10)

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

        wait(for: [closeExpect], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertNil(rootController.presentedViewController)
        XCTAssertIdentical(rootController, window?.topController)
    }

    func prepareNavigationStack(navigator: Navigator) {
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
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)
    }

    func preparePresented(navigator: Navigator) {
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
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)
    }
}

private final class TopPopRejectingNavigationController: UINavigationController {
    override func popViewController(animated: Bool) -> UIViewController? {
        return nil
    }
}
