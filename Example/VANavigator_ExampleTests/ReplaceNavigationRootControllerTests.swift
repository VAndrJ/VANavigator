//
//  ReplaceNavigationRootControllerTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 15.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import XCTest
import VANavigator

// TODO: - Messages
@MainActor
class ReplaceNavigationRootControllerTests: XCTestCase {
    var window: UIWindow?

    override func setUp() {
        window = UIWindow()
    }

    override func tearDown() {
        window = nil
    }

    func test_controllerreplaceNavigationRoot() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStack(navigator: navigator)
        let newRootIdentity = MockPushControllerNavigationIdentity()
        let navigationController = window?.rootViewController as? UINavigationController

        XCTAssertNotNil(navigationController)
        XCTAssertEqual(2, navigationController?.viewControllers.count)
        XCTAssertFalse(newRootIdentity.isEqual(to: navigationController?.viewControllers.first?.navigationIdentity))

        let expect = expectation(description: "replace")
        var responder: (UIViewController & Responder)?
        navigator.navigate(
            destination: .identity(newRootIdentity),
            strategy: .replaceNavigationRoot,
            event: ResponderMockEvent(),
            completion: { controller, _ in
                responder = controller
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(1, navigationController?.viewControllers.count)
        XCTAssertTrue(newRootIdentity.isEqual(to: navigationController?.viewControllers.first?.navigationIdentity))
        XCTAssertEqual(true, (responder as? MockViewController)?.isMockEventHandled)
    }

    func test_controllerreplaceNavigationRoot_usesFallback() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigation(navigator: navigator)
        let newRootIdentity = MockPushControllerNavigationIdentity()

        XCTAssertNil(window?.rootViewController as? UINavigationController)
        XCTAssertFalse(newRootIdentity.isEqual(to: window?.rootViewController?.navigationIdentity))

        let expect = expectation(description: "replace")
        var responder: (UIViewController & Responder)?
        navigator.navigate(
            destination: .identity(newRootIdentity),
            strategy: .replaceNavigationRoot,
            fallbackStrategies: [.closeToExisting, .present()],
            event: ResponderMockEvent(),
            completion: { controller, _ in
                responder = controller
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertFalse(newRootIdentity.isEqual(to: window?.rootViewController?.navigationIdentity))
        XCTAssertTrue(newRootIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertEqual(true, (responder as? MockViewController)?.isMockEventHandled)
    }

    func test_controllerreplaceNavigationRoot_noFallbackFail() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigation(navigator: navigator)
        let newRootIdentity = MockPushControllerNavigationIdentity()

        XCTAssertNil(window?.rootViewController as? UINavigationController)
        XCTAssertFalse(newRootIdentity.isEqual(to: window?.rootViewController?.navigationIdentity))

        let expect = expectation(description: "replace")
        var responder: (UIViewController & Responder)?
        navigator.navigate(
            destination: .identity(newRootIdentity),
            strategy: .replaceNavigationRoot,
            event: ResponderMockEvent(),
            completion: { controller, _ in
                responder = controller
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertNil(window?.rootViewController as? UINavigationController)
        XCTAssertNil(responder)
        XCTAssertFalse(newRootIdentity.isEqual(to: window?.rootViewController?.navigationIdentity))
        XCTAssertFalse(newRootIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(MockRootControllerNavigationIdentity().isEqual(to: window?.rootViewController?.navigationIdentity))
        XCTAssertTrue(MockRootControllerNavigationIdentity().isEqual(to: window?.topController?.navigationIdentity))
    }

    func test_closeNavigationPresented_completionCalledWithNilController() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let expect = expectation(description: "navigation.close")
        navigator.closeNavigationPresented(
            controller: nil,
            animated: true,
            completion: { taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)
    }

    func prepareNavigation(navigator: Navigator) {
        let expect = expectation(description: "navigation.replaceWindowRoot")
        navigator.navigate(
            destination: .identity(MockRootControllerNavigationIdentity()),
            strategy: .replaceWindowRoot(),
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)
    }

    func prepareNavigationStack(navigator: Navigator) {
        let identity = MockNavControllerNavigationIdentity(children: [
            MockRootControllerNavigationIdentity(),
            MockPopControllerNavigationIdentity(),
        ])
        let expect = expectation(description: "navigation.replaceWindowRoot")
        navigator.navigate(
            destination: .identity(identity),
            strategy: .replaceWindowRoot(),
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)
    }
}
