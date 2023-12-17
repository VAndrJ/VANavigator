//
//  PresentOrCloseToExistingControllerTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 15.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import XCTest
import VANavigator

// TODO: - Messages
@MainActor
class PresentOrCloseToExistingControllerTests: XCTestCase {
    var window: UIWindow?

    override func setUp() {
        window = UIWindow()
    }

    override func tearDown() {
        window = nil
    }

    func test_controllerCloseToExisting() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigation(navigator: navigator)
        let identity = MockRootControllerNavigationIdentity()

        XCTAssertFalse(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertNotNil(window?.findController(destination: .identity(identity)))

        let expect = expectation(description: "replace")
        var responder: (UIViewController & Responder)?
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .closeToExistingOrPresent,
            event: ResponderMockEvent(),
            completion: { controller, isSuccess in
                responder = controller
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertTrue(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertEqual(true, (window?.topController as? MockViewController)?.isMockEventHandled)
        XCTAssertEqual(true, (responder as? MockViewController)?.isMockEventHandled)
    }

    func test_controllerCloseToExisting_presented() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigation(navigator: navigator)
        let identity = MockPopControllerNavigationIdentity()

        XCTAssertFalse(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertNil(window?.findController(destination: .identity(identity)))

        let expect = expectation(description: "replace")
        var responder: (UIViewController & Responder)?
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .closeToExistingOrPresent,
            event: ResponderMockEvent(),
            completion: { controller, isSuccess in
                responder = controller
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertTrue(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertEqual(true, (responder as? MockViewController)?.isMockEventHandled)
    }

    func test_controller_presented() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigation(navigator: navigator)
        let identity = MockPopControllerNavigationIdentity()

        XCTAssertFalse(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertNil(window?.findController(destination: .identity(identity)))

        let expect = expectation(description: "replace")
        var responder: (UIViewController & Responder)?
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .present,
            event: ResponderMockEvent(),
            completion: { controller, isSuccess in
                responder = controller
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertTrue(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertEqual(true, (responder as? MockViewController)?.isMockEventHandled)
    }

    func prepareNavigation(navigator: Navigator) {
        let expect = expectation(description: "navigation.replaceWindowRoot")
        navigator.navigate(
            chain: [
                NavigationChainLink(
                    destination: .identity(MockRootControllerNavigationIdentity()),
                    strategy: .present,
                    animated: true
                ),
                NavigationChainLink(
                    destination: .identity(MockPushControllerNavigationIdentity()),
                    strategy: .present,
                    animated: false
                ),
                NavigationChainLink(
                    destination: .controller(UIViewController()),
                    strategy: .present,
                    animated: false
                ),
            ],
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)
    }
}
