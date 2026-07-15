//
//  SplitControllerTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 17.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import XCTest
import VANavigator
import UIKit

// TODO: - Messages
class SplitControllerTests: XCTestCase, MainActorIsolated {
    var window: UIWindow?

    override func setUp() async throws {
        try await super.setUp()
        guard let windowScene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            XCTFail("A window scene is required to run split-view tests")
            return
        }
        window = UIWindow(windowScene: windowScene)
    }

    override func tearDown() async throws {
        window?.isHidden = true
        window = nil
        try await super.tearDown()
    }

    func test_primaryPush() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStack(navigator: navigator)
        let splitController = window?.rootViewController as? UISplitViewController
        let primaryIdentity = MockRootControllerNavigationIdentity()
        let secondaryIdentity = MockPopControllerNavigationIdentity()
        let newPrimaryIdentity = MockPushControllerNavigationIdentity()

        XCTAssertNotNil(splitController)
        XCTAssertTrue(primaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
        XCTAssertTrue(secondaryIdentity.isEqual(to: splitController?.viewController(for: .secondary)?.navigationIdentity))

        let expect = expectation(description: "navigation")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(newPrimaryIdentity),
            strategy: .split(strategy: .primary(action: .push)),
            completion: {
                responder = $0
                result = $1
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: splitController?.columnNavigationController(for: .primary)?.topViewController?.navigationIdentity))
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: responder?.navigationIdentity))
        let primaryControllers = splitController?.columnNavigationController(for: .primary)?.viewControllers
        XCTAssertEqual(2, primaryControllers?.filter { !($0 is UINavigationController) }.count)
        XCTAssertTrue(primaryIdentity.isEqual(to: primaryControllers?.first?.navigationIdentity))
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    func test_primaryPush_existingControllerFailsWithoutCallingUIKit() {
        let existingController = UIViewController()
        let navigationController = SplitPushInvocationRecordingNavigationController()
        navigationController.setViewControllers([existingController], animated: false)
        let splitController = MockSplitViewController(style: .doubleColumn)
        splitController.setViewController(navigationController, for: .primary)
        splitController.setViewController(UIViewController(), for: .secondary)
        window?.rootViewController = splitController
        window?.makeKeyAndVisible()
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
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(false, result)
        XCTAssertNil(responder)
        XCTAssertEqual(0, navigationController.pushInvocationCount)
        XCTAssertEqual([existingController], navigationController.viewControllers)
    }

    func test_primaryPop() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStack(navigator: navigator)
        let splitController = window?.rootViewController as? UISplitViewController
        let primaryIdentity = MockRootControllerNavigationIdentity()
        let secondaryIdentity = MockPopControllerNavigationIdentity()
        let newPrimaryIdentity = MockPushControllerNavigationIdentity()

        XCTAssertNotNil(splitController)
        XCTAssertTrue(primaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
        XCTAssertTrue(secondaryIdentity.isEqual(to: splitController?.viewController(for: .secondary)?.navigationIdentity))

        let expect = expectation(description: "navigation")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(newPrimaryIdentity),
            strategy: .split(strategy: .primary(action: .push)),
            completion: {
                responder = $0
                result = $1
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: splitController?.columnNavigationController(for: .primary)?.topViewController?.navigationIdentity))
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: responder?.navigationIdentity))
        let primaryControllers = splitController?.columnNavigationController(for: .primary)?.viewControllers
        XCTAssertEqual(2, primaryControllers?.filter { !($0 is UINavigationController) }.count)
        XCTAssertTrue(primaryIdentity.isEqual(to: primaryControllers?.first?.navigationIdentity))

        let expect1 = expectation(description: "navigation1")
        navigator.navigate(
            destination: .identity(primaryIdentity),
            strategy: .split(strategy: .primary(action: .pop)),
            completion: {
                responder = $0
                result = $1
                taskDetachedMain { expect1.fulfill() }
            }
        )

        wait(for: [expect1], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertTrue(primaryIdentity.isEqual(to: splitController?.columnNavigationController(for: .primary)?.topViewController?.navigationIdentity))
        let primaryControllers1 = splitController?.columnNavigationController(for: .primary)?.viewControllers
        XCTAssertEqual(1, primaryControllers1?.filter { !($0 is UINavigationController) }.count)
        XCTAssertTrue(primaryIdentity.isEqual(to: primaryControllers1?.first?.navigationIdentity))
        XCTAssertTrue(primaryIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    func test_primaryPop_failure() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStack(navigator: navigator)
        let splitController = window?.rootViewController as? UISplitViewController
        let primaryIdentity = MockRootControllerNavigationIdentity()
        let secondaryIdentity = MockPopControllerNavigationIdentity()
        let newPrimaryIdentity = MockPushControllerNavigationIdentity()
        let failureIdentity = MockNavControllerNavigationIdentity(children: [])

        XCTAssertNotNil(splitController)
        XCTAssertTrue(primaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
        XCTAssertTrue(secondaryIdentity.isEqual(to: splitController?.viewController(for: .secondary)?.navigationIdentity))

        let expect = expectation(description: "navigation")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(newPrimaryIdentity),
            strategy: .split(strategy: .primary(action: .push)),
            completion: {
                responder = $0
                result = $1
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: splitController?.columnNavigationController(for: .primary)?.topViewController?.navigationIdentity))
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: responder?.navigationIdentity))
        let primaryControllers = splitController?.columnNavigationController(for: .primary)?.viewControllers
        XCTAssertEqual(2, primaryControllers?.filter { !($0 is UINavigationController) }.count)
        XCTAssertTrue(primaryIdentity.isEqual(to: primaryControllers?.first?.navigationIdentity))

        let expect1 = expectation(description: "navigation1")
        navigator.navigate(
            destination: .identity(failureIdentity),
            strategy: .split(strategy: .primary(action: .pop)),
            completion: {
                responder = $0
                result = $1
                taskDetachedMain { expect1.fulfill() }
            }
        )

        wait(for: [expect1], timeout: 10)

        XCTAssertEqual(false, result)
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: splitController?.columnNavigationController(for: .primary)?.topViewController?.navigationIdentity))
        let primaryControllers1 = splitController?.columnNavigationController(for: .primary)?.viewControllers
        XCTAssertEqual(2, primaryControllers1?.filter { !($0 is UINavigationController) }.count)
        XCTAssertTrue(primaryIdentity.isEqual(to: primaryControllers1?.first?.navigationIdentity))
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    func test_primaryPop_fallback() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStack(navigator: navigator)
        let splitController = window?.rootViewController as? UISplitViewController
        let primaryIdentity = MockRootControllerNavigationIdentity()
        let secondaryIdentity = MockPopControllerNavigationIdentity()
        let newPrimaryIdentity = MockPushControllerNavigationIdentity()
        let failureIdentity = MockNavControllerNavigationIdentity(children: [])

        XCTAssertNotNil(splitController)
        XCTAssertTrue(primaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
        XCTAssertTrue(secondaryIdentity.isEqual(to: splitController?.viewController(for: .secondary)?.navigationIdentity))

        let expect = expectation(description: "navigation")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(newPrimaryIdentity),
            strategy: .split(strategy: .primary(action: .push)),
            completion: {
                responder = $0
                result = $1
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: splitController?.columnNavigationController(for: .primary)?.topViewController?.navigationIdentity))
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: responder?.navigationIdentity))
        let primaryControllers = splitController?.columnNavigationController(for: .primary)?.viewControllers
        XCTAssertEqual(2, primaryControllers?.filter { !($0 is UINavigationController) }.count)
        XCTAssertTrue(primaryIdentity.isEqual(to: primaryControllers?.first?.navigationIdentity))

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
                taskDetachedMain { expect1.fulfill() }
            }
        )

        wait(for: [expect1], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertTrue(primaryIdentity.isEqual(to: splitController?.columnNavigationController(for: .primary)?.topViewController?.navigationIdentity))
        let primaryControllers1 = splitController?.columnNavigationController(for: .primary)?.viewControllers
        XCTAssertEqual(1, primaryControllers1?.filter { !($0 is UINavigationController) }.count)
        XCTAssertTrue(primaryIdentity.isEqual(to: primaryControllers1?.first?.navigationIdentity))
        XCTAssertTrue(primaryIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    func test_primaryReplace() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStack(navigator: navigator)
        let splitController = window?.rootViewController as? UISplitViewController
        let primaryIdentity = MockRootControllerNavigationIdentity()
        let secondaryIdentity = MockPopControllerNavigationIdentity()
        let newPrimaryIdentity = MockPushControllerNavigationIdentity()

        XCTAssertNotNil(splitController)
        XCTAssertTrue(primaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
        XCTAssertTrue(secondaryIdentity.isEqual(to: splitController?.viewController(for: .secondary)?.navigationIdentity))

        let expect = expectation(description: "navigation")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(newPrimaryIdentity),
            strategy: .split(strategy: .primary(action: .replace)),
            completion: {
                responder = $0
                result = $1
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: splitController?.columnNavigationController(for: .primary)?.topViewController?.navigationIdentity))
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: responder?.navigationIdentity))
        if splitController?.isSingleNavigation == false {
            XCTAssertTrue(secondaryIdentity.isEqual(to: splitController?.viewController(for: .secondary)?.navigationIdentity))
        }
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    func test_secondaryPush() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStack(navigator: navigator)
        let splitController = window?.rootViewController as? UISplitViewController
        let primaryIdentity = MockRootControllerNavigationIdentity()
        let secondaryIdentity = MockPopControllerNavigationIdentity()
        let newPrimaryIdentity = MockPushControllerNavigationIdentity()

        XCTAssertNotNil(splitController)
        XCTAssertTrue(primaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
        XCTAssertTrue(secondaryIdentity.isEqual(to: splitController?.viewController(for: .secondary)?.navigationIdentity))

        let expect = expectation(description: "navigation")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(newPrimaryIdentity),
            strategy: .split(strategy: .secondary(action: .push)),
            completion: {
                responder = $0
                result = $1
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: responder?.navigationIdentity))
        let secondaryControllers = splitController?.columnNavigationController(for: .secondary)?.viewControllers
        XCTAssertEqual(2, secondaryControllers?.filter { !($0 is UINavigationController) }.count)
        XCTAssertTrue(secondaryIdentity.isEqual(to: secondaryControllers?.first?.navigationIdentity))
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    func test_secondaryPop() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStack(navigator: navigator)
        let splitController = window?.rootViewController as? UISplitViewController
        let primaryIdentity = MockRootControllerNavigationIdentity()
        let secondaryIdentity = MockPopControllerNavigationIdentity()
        let newPrimaryIdentity = MockPushControllerNavigationIdentity()

        XCTAssertNotNil(splitController)
        XCTAssertTrue(primaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
        XCTAssertTrue(secondaryIdentity.isEqual(to: splitController?.viewController(for: .secondary)?.navigationIdentity))

        let expect = expectation(description: "navigation")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(newPrimaryIdentity),
            strategy: .split(strategy: .secondary(action: .push)),
            completion: {
                responder = $0
                result = $1
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: responder?.navigationIdentity))
        let secondaryControllers = splitController?.columnNavigationController(for: .secondary)?.viewControllers
        XCTAssertEqual(2, secondaryControllers?.filter { !($0 is UINavigationController) }.count)
        XCTAssertTrue(secondaryIdentity.isEqual(to: secondaryControllers?.first?.navigationIdentity))

        let expect1 = expectation(description: "navigation1")
        navigator.navigate(
            destination: .identity(secondaryIdentity),
            strategy: .split(strategy: .secondary(action: .pop)),
            completion: {
                responder = $0
                result = $1
                taskDetachedMain { expect1.fulfill() }
            }
        )

        wait(for: [expect1], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertTrue(secondaryIdentity.isEqual(to: splitController?.columnNavigationController(for: .secondary)?.topViewController?.navigationIdentity))
        let secondaryControllers1 = splitController?.columnNavigationController(for: .secondary)?.viewControllers
        XCTAssertEqual(1, secondaryControllers1?.filter { !($0 is UINavigationController) }.count)
        XCTAssertTrue(secondaryIdentity.isEqual(to: secondaryControllers1?.first?.navigationIdentity))
        XCTAssertTrue(secondaryIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    func test_secondaryPop_failure() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStack(navigator: navigator)
        let splitController = window?.rootViewController as? UISplitViewController
        let primaryIdentity = MockRootControllerNavigationIdentity()
        let secondaryIdentity = MockPopControllerNavigationIdentity()
        let newPrimaryIdentity = MockPushControllerNavigationIdentity()
        let failureIdentity = MockNavControllerNavigationIdentity(children: [])

        XCTAssertNotNil(splitController)
        XCTAssertTrue(primaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
        XCTAssertTrue(secondaryIdentity.isEqual(to: splitController?.viewController(for: .secondary)?.navigationIdentity))

        let expect = expectation(description: "navigation")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(newPrimaryIdentity),
            strategy: .split(strategy: .secondary(action: .push)),
            completion: {
                responder = $0
                result = $1
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: responder?.navigationIdentity))
        let secondaryControllers = splitController?.columnNavigationController(for: .secondary)?.viewControllers
        XCTAssertEqual(2, secondaryControllers?.filter { !($0 is UINavigationController) }.count)
        XCTAssertTrue(secondaryIdentity.isEqual(to: secondaryControllers?.first?.navigationIdentity))

        let expect1 = expectation(description: "navigation1")
        navigator.navigate(
            destination: .identity(failureIdentity),
            strategy: .split(strategy: .secondary(action: .pop)),
            completion: {
                responder = $0
                result = $1
                taskDetachedMain { expect1.fulfill() }
            }
        )

        wait(for: [expect1], timeout: 10)

        XCTAssertEqual(false, result)
        let secondaryControllers1 = splitController?.columnNavigationController(for: .secondary)?.viewControllers
        XCTAssertEqual(2, secondaryControllers1?.filter { !($0 is UINavigationController) }.count)
        XCTAssertTrue(secondaryIdentity.isEqual(to: secondaryControllers1?.first?.navigationIdentity))
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    func test_secondaryPop_fallback() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStack(navigator: navigator)
        let splitController = window?.rootViewController as? UISplitViewController
        let primaryIdentity = MockRootControllerNavigationIdentity()
        let secondaryIdentity = MockPopControllerNavigationIdentity()
        let newPrimaryIdentity = MockPushControllerNavigationIdentity()
        let failureIdentity = MockNavControllerNavigationIdentity(children: [])

        XCTAssertNotNil(splitController)
        XCTAssertTrue(primaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
        XCTAssertTrue(secondaryIdentity.isEqual(to: splitController?.viewController(for: .secondary)?.navigationIdentity))

        let expect = expectation(description: "navigation")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(newPrimaryIdentity),
            strategy: .split(strategy: .secondary(action: .push)),
            completion: {
                responder = $0
                result = $1
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: responder?.navigationIdentity))
        let secondaryControllers = splitController?.columnNavigationController(for: .secondary)?.viewControllers
        XCTAssertEqual(2, secondaryControllers?.filter { !($0 is UINavigationController) }.count)
        XCTAssertTrue(secondaryIdentity.isEqual(to: secondaryControllers?.first?.navigationIdentity))

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
                taskDetachedMain { expect1.fulfill() }
            }
        )

        wait(for: [expect1], timeout: 10)

        XCTAssertEqual(true, result)
        let secondaryControllers1 = splitController?.columnNavigationController(for: .secondary)?.viewControllers
        XCTAssertEqual(1, secondaryControllers1?.filter { !($0 is UINavigationController) }.count)
        XCTAssertTrue(secondaryIdentity.isEqual(to: secondaryControllers1?.first?.navigationIdentity))
        XCTAssertTrue(secondaryIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    func test_secondaryReplace() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStack(navigator: navigator)
        let splitController = window?.rootViewController as? UISplitViewController
        let primaryIdentity = MockRootControllerNavigationIdentity()
        let secondaryIdentity = MockPopControllerNavigationIdentity()
        let newPrimaryIdentity = MockPushControllerNavigationIdentity()

        XCTAssertNotNil(splitController)
        XCTAssertTrue(primaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
        XCTAssertTrue(secondaryIdentity.isEqual(to: splitController?.viewController(for: .secondary)?.navigationIdentity))

        let expect = expectation(description: "navigation")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(newPrimaryIdentity),
            strategy: .split(strategy: .secondary(action: .replace)),
            completion: {
                responder = $0
                result = $1
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: splitController?.columnNavigationController(for: .secondary)?.topViewController?.navigationIdentity))
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: responder?.navigationIdentity))
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    func test_primaryReplace_withoutColumnNavigation_fallback() {
        assertSplitColumnNavigationFallback(
            strategy: .primary(action: .replace),
            failedColumn: .primary
        )
    }

    func test_primaryPush_withoutColumnNavigation_fallback() {
        assertSplitColumnNavigationFallback(
            strategy: .primary(action: .push),
            failedColumn: .primary
        )
    }

    func test_secondaryReplace_withoutColumnNavigation_fallback() {
        assertSplitColumnNavigationFallback(
            strategy: .secondary(action: .replace),
            failedColumn: .secondary
        )
    }

    func test_secondaryPush_withoutColumnNavigation_fallback() {
        assertSplitColumnNavigationFallback(
            strategy: .secondary(action: .push),
            failedColumn: .secondary
        )
    }

    func assertSplitColumnNavigationFallback(
        strategy: SplitStrategy,
        failedColumn: UISplitViewController.Column,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStackWithMissingColumnNavigation(failedColumn: failedColumn)
        let splitController = window?.rootViewController as? MissingColumnNavigationSplitViewController
        let newIdentity = MockPushControllerNavigationIdentity()

        XCTAssertNotNil(splitController, file: file, line: line)

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
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(true, result, file: file, line: line)
        XCTAssertTrue(newIdentity.isEqual(to: responder?.navigationIdentity), file: file, line: line)
        XCTAssertTrue(newIdentity.isEqual(to: window?.rootViewController?.navigationIdentity), file: file, line: line)
    }

    func prepareNavigationStack(navigator: Navigator) {
        let expect = expectation(description: "navigation.prepareNavigationStack")
        navigator.navigate(
            destination: .identity(MockSplitControllerNavigationIdentity(
                primary: MockRootControllerNavigationIdentity(),
                secondary: MockPopControllerNavigationIdentity()
            )),
            strategy: .replaceWindowRoot(),
            animated: false,
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)
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

    func test_primaryPop_withoutSplit_fallback() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStackWithoutSplit(navigator: navigator)
        let splitController = window?.rootViewController as? UISplitViewController
        let primaryIdentity = MockRootControllerNavigationIdentity()
        let newPrimaryIdentity = MockPushControllerNavigationIdentity()

        XCTAssertNil(splitController)
        XCTAssertTrue(primaryIdentity.isEqual(to: window?.topController?.navigationIdentity))

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
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: responder?.navigationIdentity))
    }

    func prepareNavigationStackWithoutSplit(navigator: Navigator) {
        let expect = expectation(description: "navigation.prepareNavigationStack")
        navigator.navigate(
            destination: .identity(MockRootControllerNavigationIdentity()),
            strategy: .replaceWindowRoot(),
            animated: false,
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)
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
