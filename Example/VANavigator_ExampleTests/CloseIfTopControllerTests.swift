//
//  CloseIfTopControllerTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 07.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import XCTest
import VANavigator
@testable import VANavigator_Example

// TODO: - Messages
@MainActor
class CloseIfTopControllerTests: XCTestCase {
    var window: UIWindow?

    override func setUp() {
        window = UIWindow()
    }

    override func tearDown() {
        window = nil
    }

    func test_controllerDismiss() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        preparePresented(navigator: navigator)
        let topIdentity = MockPushControllerNavigationIdentity()

        XCTAssertTrue(topIdentity.isEqual(to: window?.topController?.navigationIdentity))

        let expect = expectation(description: "navigation.closeIfTop")
        navigator.navigate(
            destination: .identity(topIdentity),
            strategy: .closeIfTop(),
            completion: { taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)

        let expectedIdentity = MockPopControllerNavigationIdentity()

        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    func test_controllerPop_notDismissed() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        preparePresented(navigator: navigator)
        let topIdentity = MockPushControllerNavigationIdentity()

        XCTAssertTrue(topIdentity.isEqual(to: window?.topController?.navigationIdentity))

        let expect = expectation(description: "navigation.closeIfTop")
        navigator.navigate(
            destination: .identity(topIdentity),
            strategy: .closeIfTop(tryToDismiss: false),
            completion: { taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)

        let expectedIdentity = topIdentity

        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    func test_controllerPop() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStack(navigator: navigator)
        let topIdentity = MockPushControllerNavigationIdentity()
        let navigationController = window?.rootViewController as? UINavigationController

        XCTAssertTrue(topIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertEqual(3, navigationController?.viewControllers.count)

        let expect = expectation(description: "navigation.closeIfTop")
        navigator.navigate(
            destination: .identity(topIdentity),
            strategy: .closeIfTop(),
            event: ResponderMockEvent(),
            completion: { taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)

        let expectedIdentity = MockPopControllerNavigationIdentity()
        
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertEqual(2, navigationController?.viewControllers.count)
        XCTAssertTrue(expectedIdentity.isEqual(to: navigationController?.topViewController?.navigationIdentity))
    }

    func test_controllerPop_notPopped() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStack(navigator: navigator)
        let topIdentity = MockPushControllerNavigationIdentity()
        let navigationController = window?.rootViewController as? UINavigationController

        XCTAssertTrue(topIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertEqual(3, navigationController?.viewControllers.count)

        let expect = expectation(description: "navigation.closeIfTop")
        navigator.navigate(
            destination: .identity(topIdentity),
            strategy: .closeIfTop(tryToPop: false),
            event: ResponderMockEvent(),
            completion: { taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)

        let expectedIdentity = topIdentity

        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertEqual(3, navigationController?.viewControllers.count)
        XCTAssertTrue(expectedIdentity.isEqual(to: navigationController?.topViewController?.navigationIdentity))
    }

    func prepareNavigationStack(navigator: Navigator) {
        let expect = expectation(description: "navigation.prepareNavigationStack")
        navigator.navigate(
            chain: [
                (destination: .identity(MockRootControllerNavigationIdentity()), strategy: .push(alwaysEmbedded: true), animated: false),
                (destination: .identity(MockPopControllerNavigationIdentity()), strategy: .push(alwaysEmbedded: true), animated: false),
                (destination: .identity(MockPushControllerNavigationIdentity()), strategy: .push(alwaysEmbedded: true), animated: false),
            ],
            completion: { taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)
    }

    func preparePresented(navigator: Navigator) {
        let expect = expectation(description: "navigation.prepareNavigationStack")
        navigator.navigate(
            chain: [
                (destination: .identity(MockRootControllerNavigationIdentity()), strategy: .present, animated: false),
                (destination: .identity(MockPopControllerNavigationIdentity()), strategy: .present, animated: false),
                (destination: .identity(MockPushControllerNavigationIdentity()), strategy: .present, animated: false),
            ],
            completion: { taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)
    }
}
