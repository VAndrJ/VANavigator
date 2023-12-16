//
//  PushControllerTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 07.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import XCTest
import VANavigator

// TODO: - Messages
@MainActor
class PushControllerTests: XCTestCase {
    var window: UIWindow?

    override func setUp() {
        window = UIWindow()
    }

    override func tearDown() {
        window = nil
    }

    func test_controllerPushOntoNavigationStack() {
        controllerPushOntoNavigationStack(alwaysEmbedded: false)
    }

    func test_controllerPushOntoNavigationStack_fallbackPresentNavigation() {
        controllerPushOntoNavigationStack(alwaysEmbedded: true)
    }

    func test_controllerPushOntoNavigationStack_failWithoutFallback() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStack(navigator: navigator, alwaysEmbedded: false)

        let identity = MockPushControllerNavigationIdentity()
        _ = push(
            navigator: navigator,
            identity: identity,
            alwaysEmbedded: nil
        )

        XCTAssertTrue(MockRootControllerNavigationIdentity().isEqual(to: window?.rootViewController?.navigationIdentity))
        XCTAssertTrue(MockRootControllerNavigationIdentity().isEqual(to: window?.topController?.navigationIdentity))
    }

    func test_controllerPresentWithNavigation() {
        controllerPresentWithNavigation(alwaysEmbedded: false)
    }

    func test_controllerPresentWithNavigation_embedded() {
        controllerPresentWithNavigation(alwaysEmbedded: true)
    }

    func controllerPresentWithNavigation(
        alwaysEmbedded: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStack(navigator: navigator, alwaysEmbedded: false)

        let identity = MockPushControllerNavigationIdentity()
        let responder = push(
            navigator: navigator,
            identity: identity,
            alwaysEmbedded: alwaysEmbedded
        )

        // Check that controller was presented
        // and it is the top view controller.
        let expectedIdentity = identity

        XCTAssertNil(window?.rootViewController as? UINavigationController, file: file, line: line)
        if alwaysEmbedded {
            let navigationController = window?.rootViewController?.presentedViewController as? UINavigationController

            XCTAssertNotNil(navigationController, file: file, line: line)
            XCTAssertTrue(navigationController?.viewControllers.count == 1, file: file, line: line)
            XCTAssertTrue(expectedIdentity.isEqual(to: navigationController?.topViewController?.navigationIdentity), file: file, line: line)
        } else {
            XCTAssertTrue(expectedIdentity.isEqual(to: window?.rootViewController?.presentedViewController?.navigationIdentity), "expected not equal to top", file: file, line: line)
        }
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity), file: file, line: line)
        XCTAssertTrue(expectedIdentity.isEqual(to: responder?.navigationIdentity), file: file, line: line)
        XCTAssertEqual(true, (responder as? MockViewController)?.isMockEventHandled, file: file, line: line)
    }

    func controllerPushOntoNavigationStack(
        alwaysEmbedded: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStack(navigator: navigator, alwaysEmbedded: true)

        let identity = MockPushControllerNavigationIdentity()
        let responder = push(
            navigator: navigator,
            identity: identity,
            alwaysEmbedded: alwaysEmbedded
        )

        // Check that controller was pushed
        // and it is the top view controller.
        let rootNavigationController = window?.rootViewController as? UINavigationController
        let expectedIdentity = identity

        XCTAssertTrue(rootNavigationController?.viewControllers.count == 2, file: file, line: line)
        XCTAssertTrue(expectedIdentity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity), file: file, line: line)
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity), file: file, line: line)
        XCTAssertTrue(expectedIdentity.isEqual(to: responder?.navigationIdentity), file: file, line: line)
        XCTAssertEqual(true, (responder as? MockViewController)?.isMockEventHandled, file: file, line: line)
    }

    func push(navigator: Navigator, identity: NavigationIdentity, alwaysEmbedded: Bool?) -> (UIViewController & Responder)? {
        let expect = expectation(description: "push")
        let responder = navigator.navigate(
            destination: .identity(identity),
            strategy: .push,
            fallback: alwaysEmbedded.map {
                $0 ? NavigationChainLink(
                    destination: .identity(MockNavControllerNavigationIdentity(childIdentity: [identity])),
                    strategy: .present,
                    animated: true
                ) : NavigationChainLink(
                    destination: .identity(identity),
                    strategy: .present,
                    animated: true
                )
            },
            event: ResponderMockEvent(),
            completion: { taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)

        return responder
    }

    func prepareNavigationStack(navigator: Navigator, alwaysEmbedded: Bool) {
        let identity = MockRootControllerNavigationIdentity()
        let expect = expectation(description: "navigation.replaceWindowRoot")
        navigator.navigate(
            destination: .identity(alwaysEmbedded ? MockNavControllerNavigationIdentity(childIdentity: [identity]) : identity),
            strategy: .replaceWindowRoot(),
            completion: { taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)
    }
}
