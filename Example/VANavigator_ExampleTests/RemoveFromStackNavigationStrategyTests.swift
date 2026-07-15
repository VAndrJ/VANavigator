//
//  RemoveFromStackNavigationStrategyTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 01.03.2024.
//  Copyright © 2024 Volodymyr Andriienko. All rights reserved.
//

import UIKit
import VANavigator
import XCTest

class RemoveFromStackNavigationStrategyTests: XCTestCase {
    var window: UIWindow?

    override func setUp() async throws {
        window = UIWindow()
    }

    override func tearDown() async throws {
        window = nil
    }

    func test_controllerPop_fail() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let childIdentity = MockRootControllerNavigationIdentity()
        let identity = MockNavControllerNavigationIdentity(children: [
            childIdentity
        ])
        await prepareNavigationStack(navigator: navigator, identity: identity)
        let rootNavigationController = window?.rootViewController as? UINavigationController

        XCTAssertTrue(rootNavigationController?.viewControllers.count == 1)
        XCTAssertTrue(childIdentity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity))

        let expect = expectation(description: "removeFromStack")
        var result: Bool?
        navigator.navigate(
            destination: .identity(childIdentity),
            strategy: .removeFromNavigationStack,
            event: ResponderMockEvent(),
            completion: { _, isSuccess in
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        XCTAssertEqual(false, result)
        XCTAssertTrue(rootNavigationController?.viewControllers.count == 1)
        XCTAssertTrue(childIdentity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity))
    }

    func test_controllerPop_singleFallback() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let childIdentity = MockRootControllerNavigationIdentity()
        await prepareNavigationStack(navigator: navigator, identity: childIdentity)
        let expectedIdentity = MockPushControllerNavigationIdentity()

        XCTAssertTrue(childIdentity.isEqual(to: window?.rootViewController?.navigationIdentity))

        let expect = expectation(description: "removeFromStack")
        var result: Bool?
        navigator.navigate(
            destination: .identity(childIdentity),
            strategy: .removeFromNavigationStack,
            fallback: .init(
                destination: .identity(expectedIdentity),
                strategy: .replaceWindowRoot(),
                animated: false
            ),
            event: ResponderMockEvent(),
            completion: { _, isSuccess in
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.rootViewController?.navigationIdentity))
    }

    func test_controller_multipleRemove() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let childIdentity = MockRootControllerNavigationIdentity()
        let expectedIdentity = MockPushControllerNavigationIdentity()
        let identity = MockNavControllerNavigationIdentity(children: [
            childIdentity,
            expectedIdentity,
        ])
        await prepareNavigationStack(navigator: navigator, identity: identity)
        let rootNavigationController = window?.rootViewController as? UINavigationController

        XCTAssertTrue(rootNavigationController?.viewControllers.count == 2)
        XCTAssertTrue(expectedIdentity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity))

        let expect = expectation(description: "removeFromStack")
        var result: Bool?
        navigator.navigate(
            destination: .identity(childIdentity),
            strategy: .removeFromNavigationStack,
            event: ResponderMockEvent(),
            completion: { _, isSuccess in
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertTrue(rootNavigationController?.viewControllers.count == 1)
        XCTAssertTrue(expectedIdentity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    func test_controllerDestination_withoutIdentityRemovesExactInstance() async {
        let rootController = UIViewController()
        let controllerToRemove = UIViewController()
        let topController = UIViewController()
        let navigationController = UINavigationController()
        navigationController.viewControllers = [rootController, controllerToRemove, topController]
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let expect = expectation(description: "remove exact controller")
        var result: Bool?

        navigator.navigate(
            destination: .controller(controllerToRemove),
            strategy: .removeFromNavigationStack,
            animated: false,
            completion: { _, isSuccess in
                result = isSuccess
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertEqual(2, navigationController.viewControllers.count)
        XCTAssertIdentical(rootController, navigationController.viewControllers.first)
        XCTAssertIdentical(topController, navigationController.topViewController)
        XCTAssertFalse(navigationController.viewControllers.contains { $0 === controllerToRemove })
    }

    func prepareNavigationStack(navigator: Navigator, identity: any NavigationIdentity) async {
        let expect = expectation(description: "navigation.replaceWindowRoot")
        navigator.navigate(
            destination: .identity(identity),
            strategy: .replaceWindowRoot(),
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        await fulfillment(of: [expect], timeout: 10)
    }
}
