//
//  ReplaceNavigationRootControllerTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 15.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit
import VANavigator
import XCTest

// TODO: - Messages
class ReplaceNavigationRootControllerTests: XCTestCase {
    var window: UIWindow?

    override func setUp() async throws {
        window = UIWindow()
    }

    override func tearDown() async throws {
        window = nil
    }

    func test_controllerreplaceNavigationRoot() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationStack(navigator: navigator)
        let newRootIdentity = MockPushControllerNavigationIdentity()
        let navigationController = window?.rootViewController as? UINavigationController

        XCTAssertNotNil(navigationController)
        XCTAssertEqual(2, navigationController?.viewControllers.count)
        XCTAssertFalse(newRootIdentity.isEqual(to: navigationController?.viewControllers.first?.navigationIdentity))

        let expect = expectation(description: "replace")
        var responder: UIViewController?
        navigator.navigate(
            destination: .identity(newRootIdentity),
            strategy: .replaceNavigationRoot,
            event: ResponderMockEvent(),
            completion: { controller, _ in
                responder = controller
                taskDetachedMain { expect.fulfill() }
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        XCTAssertEqual(1, navigationController?.viewControllers.count)
        XCTAssertTrue(newRootIdentity.isEqual(to: navigationController?.viewControllers.first?.navigationIdentity))
        XCTAssertEqual(true, (responder as? MockViewController)?.isMockEventHandled)
    }

    func test_controllerreplaceNavigationRoot_usesFallback() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigation(navigator: navigator)
        let newRootIdentity = MockPushControllerNavigationIdentity()

        XCTAssertNil(window?.rootViewController as? UINavigationController)
        XCTAssertFalse(newRootIdentity.isEqual(to: window?.rootViewController?.navigationIdentity))

        let expect = expectation(description: "replace")
        var responder: UIViewController?
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

        await fulfillment(of: [expect], timeout: 10)

        XCTAssertFalse(newRootIdentity.isEqual(to: window?.rootViewController?.navigationIdentity))
        XCTAssertTrue(newRootIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertEqual(true, (responder as? MockViewController)?.isMockEventHandled)
    }

    func test_controllerreplaceNavigationRoot_noFallbackFail() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigation(navigator: navigator)
        let newRootIdentity = MockPushControllerNavigationIdentity()

        XCTAssertNil(window?.rootViewController as? UINavigationController)
        XCTAssertFalse(newRootIdentity.isEqual(to: window?.rootViewController?.navigationIdentity))

        let expect = expectation(description: "replace")
        var responder: UIViewController?
        navigator.navigate(
            destination: .identity(newRootIdentity),
            strategy: .replaceNavigationRoot,
            event: ResponderMockEvent(),
            completion: { controller, _ in
                responder = controller
                taskDetachedMain { expect.fulfill() }
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        XCTAssertNil(window?.rootViewController as? UINavigationController)
        XCTAssertNil(responder)
        XCTAssertFalse(newRootIdentity.isEqual(to: window?.rootViewController?.navigationIdentity))
        XCTAssertFalse(newRootIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(MockRootControllerNavigationIdentity().isEqual(to: window?.rootViewController?.navigationIdentity))
        XCTAssertTrue(MockRootControllerNavigationIdentity().isEqual(to: window?.topController?.navigationIdentity))
    }

    func test_replaceNavigationRoot_rejectsNavigationControllerDestination() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationStack(navigator: navigator)
        let navigationController = window?.rootViewController as? UINavigationController
        let originalControllers = navigationController?.viewControllers
        let nestedNavigationController = UINavigationController(rootViewController: UIViewController())
        let expect = expectation(description: "replace rejected")
        var responder: UIViewController?
        var result: Bool?

        navigator.navigate(
            destination: .controller(nestedNavigationController),
            strategy: .replaceNavigationRoot,
            animated: false,
            completion: {
                responder = $0
                result = $1
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        XCTAssertEqual(false, result)
        XCTAssertNil(responder)
        XCTAssertEqual(originalControllers, navigationController?.viewControllers)
        XCTAssertNil(nestedNavigationController.parent)
    }

    func test_closeNavigationPresented_completionCalledWithNilController() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let expect = expectation(description: "navigation.close")
        navigator.closeNavigationPresented(
            controller: nil,
            animated: true,
            completion: { taskDetachedMain { expect.fulfill() } }
        )

        await fulfillment(of: [expect], timeout: 10)
    }

    func prepareNavigation(navigator: Navigator) async {
        let expect = expectation(description: "navigation.replaceWindowRoot")
        navigator.navigate(
            destination: .identity(MockRootControllerNavigationIdentity()),
            strategy: .replaceWindowRoot(),
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        await fulfillment(of: [expect], timeout: 10)
    }

    func prepareNavigationStack(navigator: Navigator) async {
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

        await fulfillment(of: [expect], timeout: 10)
    }
}
