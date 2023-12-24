//
//  PopoverTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 24.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import XCTest
import VANavigator

// TODO: - Messages
@MainActor
class PopoverTests: XCTestCase {
    var window: UIWindow?

    override func setUp() {
        window = UIWindow()
    }

    override func tearDown() {
        window = nil
    }

    func test_popover() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigation(navigator: navigator)

        XCTAssertTrue(MockRootControllerNavigationIdentity().isEqual(to: window?.rootViewController?.navigationIdentity))

        let identity = MockPushControllerNavigationIdentity()
        let expect = expectation(description: "popover")
        let expect1 = expectation(description: "presentation")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .popover(configure: { popover, controller in
                popover.sourceView = self.window?.topController?.view
                XCTAssertEqual(controller.popoverPresentationController, popover)
                expect.fulfill()
            }),
            completion: { controller, isSuccess in
                responder = controller
                result = isSuccess
                expect1.fulfill()
            }
        )

        wait(for: [expect, expect1], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertTrue(MockRootControllerNavigationIdentity().isEqual(to: window?.rootViewController?.navigationIdentity))
        XCTAssertTrue(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertEqual(responder, window?.topController)
    }

    func test_popover_failure() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())

        XCTAssertNil(window?.rootViewController)

        let identity = MockPushControllerNavigationIdentity()
        let expect = expectation(description: "presentation")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .popover(configure: { _, _ in
                XCTFail("Should not be called")
            }),
            completion: { controller, isSuccess in
                responder = controller
                result = isSuccess
                expect.fulfill()
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(false, result)
        XCTAssertNil(responder)
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
}
