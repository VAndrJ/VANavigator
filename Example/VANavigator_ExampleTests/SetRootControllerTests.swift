//
//  SetRootControllerTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 06.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import XCTest
import VANavigator
import VATextureKit

// TODO: - Messages
class SetRootControllerTests: XCTestCase, MainActorIsolated {
    var window: UIWindow?

    override func setUp() {
        window = UIWindow()
    }

    override func tearDown() {
        window = nil
    }

    func test_setRootController() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())

        XCTAssertNil(window?.rootViewController)

        let identity = MockRootControllerNavigationIdentity()
        var responder: UIViewController?
        let expect = expectation(description: "replace")
        var result: Bool?
        replaceWindowRoot(
            navigator: navigator,
            identity: identity,
            alwaysEmbedded: false,
            completion: { controller, isSuccess in
                result = isSuccess
                responder = controller
                expect.fulfill()
            }
        )

        wait(for: [expect], timeout: 10)

        // Сhecking that the `UIWindow`'s root view controller identity is equal to given
        // and it is the top view controller.
        let expectedIdentity = identity

        XCTAssertEqual(true, result)
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.rootViewController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: responder?.navigationIdentity))
        XCTAssertEqual(true, (responder as? MockViewController)?.isMockEventHandled)
        XCTAssertEqual(false, (responder as? MockRootViewController)?.isReplacedEventHandled)
    }

    func test_setRootController_embeddingInNavigation() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())

        XCTAssertNil(window?.rootViewController)

        let identity = MockRootControllerNavigationIdentity()
        replaceWindowRoot(
            navigator: navigator,
            identity: identity,
            alwaysEmbedded: true,
            completion: nil
        )

        // Сhecking that the `UIWindow`'s root view controller is `UINavigationController`
        // and it's root controller's identity is equal to given and it is the top view controller.
        let rootNavigationController = window?.rootViewController as? UINavigationController
        let expectedIdentity = identity

        XCTAssertNotNil(rootNavigationController)
        XCTAssertTrue(rootNavigationController?.viewControllers.count == 1)
        XCTAssertTrue(expectedIdentity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertEqual(true, (window?.topController as? MockViewController)?.isMockEventHandled)
        XCTAssertEqual(false, (window?.topController as? MockRootViewController)?.isReplacedEventHandled)
    }

    func test_replaceExistingRootController() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        window?.rootViewController = UIViewController()
        window?.makeKeyAndVisible()

        XCTAssertNotNil(window?.rootViewController)

        let identity = MockRootControllerNavigationIdentity()
        var responder: UIViewController?
        let expect = expectation(description: "replace")
        replaceWindowRoot(
            navigator: navigator,
            identity: identity,
            alwaysEmbedded: false,
            completion: { controller, _ in
                responder = controller
                expect.fulfill()
            }
        )
        wait(for: [expect], timeout: 10)

        // Сhecking that the `UIWindow`'s root view controller identity is equal to given
        // and it is the top view controller.
        let expectedIdentity = identity
        
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.rootViewController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: responder?.navigationIdentity))
        XCTAssertEqual(true, (responder as? MockViewController)?.isMockEventHandled)
        XCTAssertEqual(true, (responder as? MockRootViewController)?.isReplacedEventHandled)
    }

    func test_setWithoutAnimation() {
        XCTAssertNil(window?.rootViewController)
        UIView.setAnimationsEnabled(false)

        window?.set(rootViewController: UIViewController())

        XCTAssertNotNil(window?.rootViewController)
    }

    func replaceWindowRoot(
        navigator: Navigator,
        identity: any NavigationIdentity,
        alwaysEmbedded: Bool,
        completion: ((UIViewController?, Bool) -> Void)?
    ) {
        let expect = expectation(description: "navigation")
        var responder: UIViewController?
        var result = false
        navigator.navigate(
            destination: .identity(alwaysEmbedded ? MockNavControllerNavigationIdentity(children: [identity]) : identity),
            strategy: .replaceWindowRoot(),
            event: ResponderMockEvent(),
            completion: {
                responder = $0
                result = $1
                taskDetachedMain { expect.fulfill() }
            }
        )
        wait(for: [expect], timeout: 10)
        completion?(responder, result)
    }
}
