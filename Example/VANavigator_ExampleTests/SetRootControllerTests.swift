//
//  SetRootControllerTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 06.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import XCTest
import VANavigator
@testable import VANavigator_Example

// TODO: - Messages
@MainActor
class SetRootControllerTests: XCTestCase {
    var window: UIWindow?

    override func setUp() {
        window = UIWindow()
    }

    override func tearDown() {
        window = nil
    }

    func test_setRootController() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())

        XCTAssertNil(navigator.window?.rootViewController)

        let identity = MockRootControllerNavigationIdentity()
        let responder = replaceWindowRoot(
            navigator: navigator,
            identity: identity,
            alwaysEmbedded: false
        )

        // Сhecking that the `UIWindow`'s root view controller identity is equal to given
        // and it is the top view controller.
        let expectedIdentity = identity

        XCTAssertTrue(expectedIdentity.isEqual(to: navigator.window?.rootViewController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: navigator.window?.topController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: responder?.navigationIdentity))
        XCTAssertEqual(true, (responder as? MockRootViewController)?.isMockEventHandled)
        XCTAssertEqual(false, (responder as? MockRootViewController)?.isReplacedEventHandled)
    }

    func test_setRootController_embeddingInNavigation() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())

        XCTAssertNil(navigator.window?.rootViewController)

        let identity = MockRootControllerNavigationIdentity()
        let responder = replaceWindowRoot(
            navigator: navigator,
            identity: identity,
            alwaysEmbedded: true
        )

        // Сhecking that the `UIWindow`'s root view controller is `UINavigationController`
        // and it's root controller's identity is equal to given and it is the top view controller.
        let rootNavigationController = navigator.window?.rootViewController as? UINavigationController
        let expectedIdentity = identity

        XCTAssertNotNil(rootNavigationController)
        XCTAssertTrue(rootNavigationController?.viewControllers.count == 1)
        XCTAssertTrue(expectedIdentity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: navigator.window?.topController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: responder?.navigationIdentity))
        XCTAssertEqual(true, (responder as? MockRootViewController)?.isMockEventHandled)
        XCTAssertEqual(false, (responder as? MockRootViewController)?.isReplacedEventHandled)
    }

    func test_replaceExistingRootController() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        window?.rootViewController = UIViewController()
        window?.makeKeyAndVisible()

        XCTAssertNotNil(navigator.window?.rootViewController)

        let identity = MockRootControllerNavigationIdentity()
        let responder = replaceWindowRoot(
            navigator: navigator,
            identity: identity,
            alwaysEmbedded: false
        )

        // Сhecking that the `UIWindow`'s root view controller identity is equal to given
        // and it is the top view controller.
        let expectedIdentity = identity
        
        XCTAssertTrue(expectedIdentity.isEqual(to: navigator.window?.rootViewController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: navigator.window?.topController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: responder?.navigationIdentity))
        XCTAssertEqual(true, (responder as? MockRootViewController)?.isMockEventHandled)
        XCTAssertEqual(true, (responder as? MockRootViewController)?.isReplacedEventHandled)
    }

    func replaceWindowRoot(
        navigator: Navigator,
        identity: NavigationIdentity,
        alwaysEmbedded: Bool
    ) -> (UIViewController & Responder)? {
        let expect = expectation(description: "navigation")
        let responder = navigator.navigate(
            destination: .identity(identity),
            strategy: .replaceWindowRoot(alwaysEmbedded: alwaysEmbedded),
            event: ResponderMockEvent(),
            completion: { taskDetachedMain { expect.fulfill() } }
        )
        wait(for: [expect], timeout: 10)

        return responder
    }
}
