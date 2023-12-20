//
//  SplitControllerTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 17.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import XCTest
import VANavigator

// TODO: - Messages
// swiftlint:disable type_body_length
@MainActor
class SplitControllerTests: XCTestCase {
    var window: UIWindow?

    override func setUp() {
        window = UIWindow()
    }

    override func tearDown() {
        window = nil
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
        var responder: (UIViewController & Responder)?
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
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: responder?.navigationIdentity))
        let primaryControllers = (splitController?.viewController(for: .primary)?.navigationController as? UINavigationController)?.viewControllers
        XCTAssertEqual(2, primaryControllers?.filter { !($0 is UINavigationController) }.count)
        XCTAssertTrue(primaryIdentity.isEqual(to: primaryControllers?.first?.navigationIdentity))
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: window?.topController?.navigationIdentity))
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
        var responder: (UIViewController & Responder)?
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
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: responder?.navigationIdentity))
        let primaryControllers = (splitController?.viewController(for: .primary)?.navigationController as? UINavigationController)?.viewControllers
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
        XCTAssertTrue(primaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
        let primaryControllers1 = (splitController?.viewController(for: .primary)?.navigationController as? UINavigationController)?.viewControllers
        XCTAssertEqual(1, primaryControllers1?.filter { !($0 is UINavigationController) }.count)
        XCTAssertTrue(primaryIdentity.isEqual(to: primaryControllers?.first?.navigationIdentity))
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
        var responder: (UIViewController & Responder)?
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
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: responder?.navigationIdentity))
        let primaryControllers = (splitController?.viewController(for: .primary)?.navigationController as? UINavigationController)?.viewControllers
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
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
        let primaryControllers1 = (splitController?.viewController(for: .primary)?.navigationController as? UINavigationController)?.viewControllers
        XCTAssertEqual(2, primaryControllers1?.filter { !($0 is UINavigationController) }.count)
        XCTAssertTrue(primaryIdentity.isEqual(to: primaryControllers?.first?.navigationIdentity))
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
        var responder: (UIViewController & Responder)?
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
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: responder?.navigationIdentity))
        let primaryControllers = (splitController?.viewController(for: .primary)?.navigationController as? UINavigationController)?.viewControllers
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
        XCTAssertTrue(primaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
        let primaryControllers1 = (splitController?.viewController(for: .primary)?.navigationController as? UINavigationController)?.viewControllers
        XCTAssertEqual(1, primaryControllers1?.filter { !($0 is UINavigationController) }.count)
        XCTAssertTrue(primaryIdentity.isEqual(to: primaryControllers?.first?.navigationIdentity))
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
        var responder: (UIViewController & Responder)?
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
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: splitController?.viewController(for: .primary)?.navigationIdentity))
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
        var responder: (UIViewController & Responder)?
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
        let secondaryControllers = (splitController?.viewController(for: .secondary)?.navigationController as? UINavigationController)?.viewControllers
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
        var responder: (UIViewController & Responder)?
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
        let secondaryControllers = (splitController?.viewController(for: .secondary)?.navigationController as? UINavigationController)?.viewControllers
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
        XCTAssertTrue(secondaryIdentity.isEqual(to: splitController?.viewController(for: .secondary)?.navigationIdentity))
        let secondaryControllers1 = (splitController?.viewController(for: .secondary)?.navigationController as? UINavigationController)?.viewControllers
        XCTAssertEqual(1, secondaryControllers1?.filter { !($0 is UINavigationController) }.count)
        XCTAssertTrue(secondaryIdentity.isEqual(to: secondaryControllers?.first?.navigationIdentity))
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
        var responder: (UIViewController & Responder)?
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
        let secondaryControllers = (splitController?.viewController(for: .secondary)?.navigationController as? UINavigationController)?.viewControllers
        XCTAssertEqual(2, secondaryControllers?.filter { !($0 is UINavigationController) }.count)
        XCTAssertTrue(secondaryIdentity.isEqual(to: secondaryControllers?.first?.navigationIdentity))

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
        let secondaryControllers1 = (splitController?.viewController(for: .secondary)?.navigationController as? UINavigationController)?.viewControllers
        XCTAssertEqual(2, secondaryControllers1?.filter { !($0 is UINavigationController) }.count)
        XCTAssertTrue(secondaryIdentity.isEqual(to: secondaryControllers?.first?.navigationIdentity))
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
        var responder: (UIViewController & Responder)?
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
        let secondaryControllers = (splitController?.viewController(for: .secondary)?.navigationController as? UINavigationController)?.viewControllers
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
        let secondaryControllers1 = (splitController?.viewController(for: .primary)?.navigationController as? UINavigationController)?.viewControllers
        XCTAssertEqual(1, secondaryControllers1?.filter { !($0 is UINavigationController) }.count)
        XCTAssertTrue(secondaryIdentity.isEqual(to: secondaryControllers?.first?.navigationIdentity))
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
        var responder: (UIViewController & Responder)?
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
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: splitController?.viewController(for: .secondary)?.navigationIdentity))
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: responder?.navigationIdentity))
        XCTAssertTrue(newPrimaryIdentity.isEqual(to: window?.topController?.navigationIdentity))
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
        var responder: (UIViewController & Responder)?
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
// swiftlint:enable type_body_length
