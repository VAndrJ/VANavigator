//
//  PushOrPopControllerTests.swift
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
class PushOrPopControllerTests: XCTestCase {
    var window: UIWindow?

    override func setUp() async throws {
        window = UIWindow()
    }

    override func tearDown() async throws {
        window = nil
    }

    func test_controllerPop() {
        controllerPopInNavigationStack(isTop: false)
    }

    func test_controllerPop_notPoppedWhenTop() {
        controllerPopInNavigationStack(isTop: true)
    }

    func test_controllerPush_whenNotInStack() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStack(navigator: navigator, alwaysEmbedded: true)
        let identity = MockPopControllerNavigationIdentity()

        let rootNavigationController = window?.rootViewController as? UINavigationController

        XCTAssertTrue(rootNavigationController?.viewControllers.count == 1)
        XCTAssertFalse(identity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity))

        let expect = expectation(description: "pushOrPop")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .popToExisting(includingTabs: false),
            fallback: NavigationChainLink(
                destination: .identity(identity),
                strategy: .push(),
                animated: true
            ),
            event: ResponderMockEvent(),
            completion: {
                responder = $0
                result = $1
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        // Check that controller was pushed
        // and it is the top view controller.
        let expectedIdentity = identity

        XCTAssertEqual(true, result)
        XCTAssertTrue(rootNavigationController?.viewControllers.count == 2)
        XCTAssertTrue(expectedIdentity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: responder?.navigationIdentity))
        XCTAssertEqual(true, (responder as? MockViewController)?.isMockEventHandled)
        XCTAssertEqual(false, (responder as? MockPopViewController)?.isPoppedEventHandled)
    }

    func test_popToExisting_navigationContainerDoesNotPopToItself() {
        let identity = MockNavControllerNavigationIdentity(children: [])
        let childController = UIViewController()
        let navigationController = PopInvocationRecordingNavigationController()
        navigationController.setViewControllers([childController], animated: false)
        navigationController.navigationIdentity = identity
        window?.rootViewController = navigationController
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let expect = expectation(description: "pop")
        var responder: UIViewController?
        var result: Bool?

        navigator.navigate(
            destination: .identity(identity),
            strategy: .popToExisting(includingTabs: false),
            animated: false,
            completion: { controller, isSuccess in
                responder = controller
                result = isSuccess
                expect.fulfill()
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertIdentical(navigationController, responder)
        XCTAssertEqual(0, navigationController.popInvocationCount)
        XCTAssertEqual([childController], navigationController.viewControllers)
    }

    func test_popToExisting_reportsFailureWhenUIKitRejectsPop() {
        let targetController = UIViewController()
        let topController = UIViewController()
        let navigationController = PopRejectingNavigationController()
        navigationController.setViewControllers([targetController, topController], animated: false)
        window?.rootViewController = navigationController
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let expect = expectation(description: "pop rejected")
        var result: Bool?

        navigator.navigate(
            destination: .controller(targetController),
            strategy: .popToExisting(includingTabs: false),
            animated: false,
            completion: { _, isSuccess in
                result = isSuccess
                expect.fulfill()
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(false, result)
        XCTAssertEqual([targetController, topController], navigationController.viewControllers)
        XCTAssertIdentical(topController, navigationController.topViewController)
    }

    func test_controllerPop_single() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStack(navigator: navigator, alwaysEmbedded: true)
        let identity = MockRootControllerNavigationIdentity()

        let rootNavigationController = window?.rootViewController as? UINavigationController

        XCTAssertTrue(rootNavigationController?.viewControllers.count == 1)
        XCTAssertTrue(identity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity))

        let expect = expectation(description: "pushOrPop")
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .closeIfTop(),
            event: ResponderMockEvent(),
            completion: { _, isSuccess in
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        // Check that controller was not popped
        // and it is the top view controller.
        let expectedIdentity = identity

        XCTAssertEqual(false, result)
        XCTAssertTrue(rootNavigationController?.viewControllers.count == 1)
        XCTAssertTrue(expectedIdentity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    func test_controllerPop_singleFallback() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStack(navigator: navigator, alwaysEmbedded: true)
        let identity = MockRootControllerNavigationIdentity()

        let rootNavigationController = window?.rootViewController as? UINavigationController

        XCTAssertTrue(rootNavigationController?.viewControllers.count == 1)
        XCTAssertTrue(identity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity))

        let expect = expectation(description: "pushOrPop")
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .closeIfTop(),
            fallback: .init(
                destination: .identity(identity),
                strategy: .push(),
                animated: false
            ),
            event: ResponderMockEvent(),
            completion: { _, isSuccess in
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        let expectedIdentity = identity

        XCTAssertEqual(true, result)
        XCTAssertTrue(rootNavigationController?.viewControllers.count == 2)
        XCTAssertTrue(expectedIdentity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    func test_controllerPop_selectingTab() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareTabNavigationStack(navigator: navigator, isTop: false)
        let identity = MockPopControllerNavigationIdentity()
        let rootTabController = window?.rootViewController as? UITabBarController

        XCTAssertTrue(rootTabController?.viewControllers?.count == 3)
        XCTAssertTrue(rootTabController?.selectedIndex == 2)
        XCTAssertFalse(identity.isEqual(to: window?.topController?.navigationIdentity))

        let expect = expectation(description: "popSelecting")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .popToExisting(includingTabs: true),
            event: ResponderMockEvent(),
            completion: {
                responder = $0
                result = $1
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        let expectedIdentity = identity

        XCTAssertEqual(true, result)
        XCTAssertTrue(rootTabController?.selectedIndex == 0)
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: responder?.navigationIdentity))
        XCTAssertEqual(true, (responder as? MockViewController)?.isMockEventHandled)
        XCTAssertEqual(true, (responder as? MockPopViewController)?.isPoppedEventHandled)
    }

    func test_controllerPop_selectingTabStaying() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareTabNavigationStack(navigator: navigator, isTop: false)
        let identity = MockPopControllerNavigationIdentity()
        let rootTabController = window?.rootViewController as? UITabBarController
        rootTabController?.selectedIndex = 0

        XCTAssertTrue(rootTabController?.viewControllers?.count == 3)
        XCTAssertTrue(rootTabController?.selectedIndex == 0)
        XCTAssertFalse(identity.isEqual(to: window?.topController?.navigationIdentity))

        let expect = expectation(description: "popSelecting")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .popToExisting(includingTabs: true),
            event: ResponderMockEvent(),
            completion: {
                responder = $0
                result = $1
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        let expectedIdentity = identity

        XCTAssertEqual(true, result)
        XCTAssertTrue(rootTabController?.selectedIndex == 0)
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: responder?.navigationIdentity))
        XCTAssertEqual(true, (responder as? MockViewController)?.isMockEventHandled)
        XCTAssertEqual(true, (responder as? MockPopViewController)?.isPoppedEventHandled)
    }

    func test_controllerPop_selectingTabFail() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareTabNavigationStack(navigator: navigator, isTop: true)
        let identity = MockPushControllerNavigationIdentity()
        let rootTabController = window?.rootViewController as? UITabBarController

        XCTAssertTrue(rootTabController?.viewControllers?.count == 3)
        XCTAssertTrue(rootTabController?.selectedIndex == 2)
        XCTAssertFalse(identity.isEqual(to: window?.topController?.navigationIdentity))

        let expect = expectation(description: "popSelecting")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .popToExisting(includingTabs: true),
            event: ResponderMockEvent(),
            completion: {
                responder = $0
                result = $1
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertNil(responder)
        XCTAssertEqual(false, result)
        XCTAssertTrue(rootTabController?.selectedIndex == 2)
        XCTAssertTrue(rootTabController?.viewControllers?.count == 3)
        XCTAssertTrue(rootTabController?.selectedIndex == 2)
        XCTAssertFalse(identity.isEqual(to: window?.topController?.navigationIdentity))
    }

    func controllerPopInNavigationStack(
        isTop: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStack(navigator: navigator, isTop: isTop)
        let identity = MockPopControllerNavigationIdentity()

        let rootNavigationController = window?.rootViewController as? UINavigationController

        XCTAssertTrue(rootNavigationController?.viewControllers.count == (isTop ? 2 : 3), file: file, line: line)
        if isTop {
            XCTAssertTrue(identity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity), file: file, line: line)
        } else {
            XCTAssertFalse(identity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity), file: file, line: line)
        }

        var responder: UIViewController?
        let expect = expectation(description: "push")
        pushOrPop(
            navigator: navigator,
            identity: identity,
            completion: { controller, _ in
                responder = controller
                expect.fulfill()
            }
        )
        wait(for: [expect], timeout: 10)
        // Check that controller was popped
        // and it is the top view controller.
        let expectedIdentity = identity

        XCTAssertTrue(rootNavigationController?.viewControllers.count == 2, file: file, line: line)
        XCTAssertTrue(expectedIdentity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity), file: file, line: line)
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity), file: file, line: line)
        XCTAssertTrue(expectedIdentity.isEqual(to: responder?.navigationIdentity), file: file, line: line)
        XCTAssertEqual(true, (responder as? MockViewController)?.isMockEventHandled, file: file, line: line)
        if !isTop {
            XCTAssertEqual(true, (responder as? MockPopViewController)?.isPoppedEventHandled, file: file, line: line)
        }
    }

    func pushOrPop(
        navigator: Navigator,
        identity: any NavigationIdentity,
        completion: ((UIViewController?, Bool) -> Void)?
    ) {
        let expect = expectation(description: "pushOrPop")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .popToExisting(includingTabs: false),
            event: ResponderMockEvent(),
            completion: {
                responder = $0
                result = $1
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)
        completion?(responder, result ?? false)
    }

    func prepareTabNavigationStack(navigator: Navigator, isTop: Bool) {
        let identity: MockNavControllerNavigationIdentity
        if isTop {
            identity = MockNavControllerNavigationIdentity(children: [
                MockRootControllerNavigationIdentity(),
                MockPopControllerNavigationIdentity(),
            ])
        } else {
            identity = MockNavControllerNavigationIdentity(children: [
                MockRootControllerNavigationIdentity(),
                MockPopControllerNavigationIdentity(),
                MockPushControllerNavigationIdentity(),
            ])
        }
        let expect = expectation(description: "navigation.replaceWindowRoot")
        navigator.navigate(
            destination: .identity(
                MockTabControllerNavigationIdentity(children: [
                    identity,
                    MockNavControllerNavigationIdentity(children: []),
                    MockNavControllerNavigationIdentity(children: []),
                ])
            ),
            strategy: .replaceWindowRoot(),
            completion: { controller, _ in
                (controller as? UITabBarController)?.selectedIndex = 2
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)
    }

    func prepareNavigationStack(navigator: Navigator, isTop: Bool) {
        let identity: MockNavControllerNavigationIdentity
        if isTop {
            identity = MockNavControllerNavigationIdentity(children: [
                MockRootControllerNavigationIdentity(),
                MockPopControllerNavigationIdentity(),
            ])
        } else {
            identity = MockNavControllerNavigationIdentity(children: [
                MockRootControllerNavigationIdentity(),
                MockPopControllerNavigationIdentity(),
                MockPushControllerNavigationIdentity(),
            ])
        }
        let expect = expectation(description: "navigation.replaceWindowRoot")
        navigator.navigate(
            destination: .identity(identity),
            strategy: .replaceWindowRoot(),
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)
    }

    func prepareNavigationStack(navigator: Navigator, alwaysEmbedded: Bool) {
        let identity = MockRootControllerNavigationIdentity()
        let expect = expectation(description: "navigation.replaceWindowRoot")
        navigator.navigate(
            destination: .identity(alwaysEmbedded ? MockNavControllerNavigationIdentity(children: [identity]) : identity),
            strategy: .replaceWindowRoot(),
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)
    }
}

private final class PopInvocationRecordingNavigationController: UINavigationController {
    private(set) var popInvocationCount = 0

    override func popToViewController(
        _ viewController: UIViewController,
        animated: Bool
    ) -> [UIViewController]? {
        popInvocationCount += 1

        return super.popToViewController(viewController, animated: animated)
    }
}

private final class PopRejectingNavigationController: UINavigationController {
    override func popToViewController(
        _ viewController: UIViewController,
        animated: Bool
    ) -> [UIViewController]? {
        return nil
    }
}
