//
//  PushViewControllerTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 07.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import XCTest
import VANavigator
@testable import VANavigator_Example

@MainActor
class PushViewControllerTests: XCTestCase {
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

    func test_controllerPushOntoNavigationStack_embeddedSame() {
        controllerPushOntoNavigationStack(alwaysEmbedded: true)
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
        XCTAssertNil(navigator.window?.rootViewController as? UINavigationController, file: file, line: line)
        if alwaysEmbedded {
            let navigationController = navigator.window?.rootViewController?.presentedViewController as? UINavigationController
            XCTAssertTrue(navigationController?.viewControllers.count == 1, file: file, line: line)
            XCTAssertTrue(identity.isEqual(to: navigationController?.topViewController?.navigationIdentity), file: file, line: line)
        } else {
            XCTAssertTrue(identity.isEqual(to: navigator.window?.rootViewController?.presentedViewController?.navigationIdentity), file: file, line: line)
        }
        XCTAssertTrue(identity.isEqual(to: navigator.window?.topController?.navigationIdentity), file: file, line: line)
        XCTAssertTrue(identity.isEqual(to: responder?.navigationIdentity), file: file, line: line)
        XCTAssertEqual(true, (responder as? MockPushViewController)?.isMockEventHandled, file: file, line: line)
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
        let rootNavigationController = navigator.window?.rootViewController as? UINavigationController
        XCTAssertTrue(rootNavigationController?.viewControllers.count == 2, file: file, line: line)
        XCTAssertTrue(identity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity), file: file, line: line)
        XCTAssertTrue(identity.isEqual(to: navigator.window?.topController?.navigationIdentity), file: file, line: line)
        XCTAssertTrue(identity.isEqual(to: responder?.navigationIdentity), file: file, line: line)
        XCTAssertEqual(true, (responder as? MockPushViewController)?.isMockEventHandled, file: file, line: line)
    }

    func push(navigator: Navigator, identity: NavigationIdentity, alwaysEmbedded: Bool) -> (UIViewController & Responder)? {
        let expect = expectation(description: "push")
        let responder = navigator.navigate(
            destination: .identity(identity),
            strategy: .push(alwaysEmbedded: alwaysEmbedded),
            event: ResponderMockEvent(),
            completion: { taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 1)

        return responder
    }

    func prepareNavigationStack(navigator: Navigator, alwaysEmbedded: Bool) {
        let identity = MockRootControllerNavigationIdentity()
        let expect = expectation(description: "navigation.replaceWindowRoot")
        navigator.navigate(
            destination: .identity(identity),
            strategy: .replaceWindowRoot(alwaysEmbedded: alwaysEmbedded),
            event: ResponderMockEvent(),
            completion: { taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 1)
    }
}
