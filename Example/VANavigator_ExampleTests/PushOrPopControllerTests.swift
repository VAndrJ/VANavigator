//
//  PushOrPopControllerTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 07.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import XCTest
import VANavigator

// TODO: - Messages
@MainActor
class PushOrPopControllerTests: XCTestCase {
    var window: UIWindow?

    override func setUp() {
        window = UIWindow()
    }

    override func tearDown() {
        window = nil
    }

    func test_controllerPop() {
        controllerPopInNavigationStack(isTop: false)
    }

    func test_controllerPop_notPoppedWhenTop() {
        controllerPopInNavigationStack(isTop: true)
    }

    func test_controllerPush_whenNotResentedInStack() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStack(navigator: navigator, alwaysEmbedded: true)
        let identity = MockPopControllerNavigationIdentity()

        let rootNavigationController = navigator.window?.rootViewController as? UINavigationController

        XCTAssertTrue(rootNavigationController?.viewControllers.count == 1)
        XCTAssertFalse(identity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity))

        let responder = pushOrPop(navigator: navigator, identity: identity)
        // Check that controller was pushed
        // and it is the top view controller.
        let expectedIdentity = identity

        XCTAssertTrue(rootNavigationController?.viewControllers.count == 2)
        XCTAssertTrue(expectedIdentity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: navigator.window?.topController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: responder?.navigationIdentity))
        XCTAssertEqual(true, (responder as? MockViewController)?.isMockEventHandled)
        XCTAssertEqual(false, (responder as? MockPopViewController)?.isPoppedEventHandled)
    }

    // TODO: - Embedded in tabbar test

    // TODO: - present embedded test

    // TODO: - Pop when presented

    func controllerPopInNavigationStack(
        isTop: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStack(navigator: navigator, isTop: isTop)
        let identity = MockPopControllerNavigationIdentity()

        let rootNavigationController = navigator.window?.rootViewController as? UINavigationController

        XCTAssertTrue(rootNavigationController?.viewControllers.count == (isTop ? 2 : 3), file: file, line: line)
        if isTop {
            XCTAssertTrue(identity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity), file: file, line: line)
        } else {
            XCTAssertFalse(identity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity), file: file, line: line)
        }

        let responder = pushOrPop(navigator: navigator, identity: identity)
        // Check that controller was popped
        // and it is the top view controller.
        let expectedIdentity = identity
        
        XCTAssertTrue(rootNavigationController?.viewControllers.count == 2, file: file, line: line)
        XCTAssertTrue(expectedIdentity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity), file: file, line: line)
        XCTAssertTrue(expectedIdentity.isEqual(to: navigator.window?.topController?.navigationIdentity), file: file, line: line)
        XCTAssertTrue(expectedIdentity.isEqual(to: responder?.navigationIdentity), file: file, line: line)
        XCTAssertEqual(true, (responder as? MockViewController)?.isMockEventHandled, file: file, line: line)
        if !isTop {
            XCTAssertEqual(true, (responder as? MockPopViewController)?.isPoppedEventHandled, file: file, line: line)
        }
    }

    func pushOrPop(navigator: Navigator, identity: NavigationIdentity) -> (UIViewController & Responder)? {
        let expect = expectation(description: "pushOrPop")
        let responder = navigator.navigate(
            destination: .identity(identity),
            strategy: .popToExistingOrPush(includingTabs: false),
            event: ResponderMockEvent(),
            completion: { taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)

        return responder
    }

    func prepareNavigationStack(navigator: Navigator, isTop: Bool) {
        let identity: MockNavControllerNavigationIdentity
        if isTop {
            identity = MockNavControllerNavigationIdentity(childIdentity: [
                MockRootControllerNavigationIdentity(),
                MockPopControllerNavigationIdentity(),
            ])
        } else {
            identity = MockNavControllerNavigationIdentity(childIdentity: [
                MockRootControllerNavigationIdentity(),
                MockPopControllerNavigationIdentity(),
                MockPushControllerNavigationIdentity(),
            ])
        }
        let expect = expectation(description: "navigation.replaceWindowRoot")
        navigator.navigate(
            destination: .identity(identity),
            strategy: .replaceWindowRoot(alwaysEmbedded: false),
            completion: { taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)
    }

    func prepareNavigationStack(navigator: Navigator, alwaysEmbedded: Bool) {
        let identity = MockRootControllerNavigationIdentity()
        let expect = expectation(description: "navigation.replaceWindowRoot")
        navigator.navigate(
            destination: .identity(identity),
            strategy: .replaceWindowRoot(alwaysEmbedded: alwaysEmbedded),
            completion: { taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)
    }
}
