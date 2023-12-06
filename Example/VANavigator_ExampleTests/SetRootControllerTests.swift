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

@MainActor
class SetRootControllerTests: XCTestCase {
    var window: UIWindow?

    override func setUp() {
        window = UIWindow()
    }

    override func tearDown() {
        window = nil
    }

    @MainActor
    func test_setRootController() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let expect = expectation(description: "navigtion")

        XCTAssertNil(navigator.window?.rootViewController)

        let identity = MockRootControllerNavigationIdentity()
        navigator.navigate(
            destination: .identity(identity),
            strategy: .replaceWindowRoot(),
            completion: { expect.fulfill() }
        )
        wait(for: [expect], timeout: 1)

        XCTAssertTrue(identity.isEqual(to: navigator.window?.rootViewController?.navigationIdentity))
        XCTAssertTrue(identity.isEqual(to: navigator.window?.topController?.navigationIdentity))
    }

    @MainActor
    func test_setRootController_embeddingInNavigation() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let expect = expectation(description: "navigtion")

        XCTAssertNil(navigator.window?.rootViewController)

        let identity = MockRootControllerNavigationIdentity()
        navigator.navigate(
            destination: .identity(identity),
            strategy: .replaceWindowRoot(alwaysEmbedded: true),
            completion: { expect.fulfill() }
        )
        wait(for: [expect], timeout: 1)
        let rootNavigationController = navigator.window?.rootViewController as? UINavigationController

        XCTAssertNotNil(rootNavigationController)
        XCTAssertTrue(rootNavigationController?.viewControllers.count == 1)
        XCTAssertTrue(identity.isEqual(to: rootNavigationController?.viewControllers.first?.navigationIdentity))
        XCTAssertTrue(identity.isEqual(to: navigator.window?.topController?.navigationIdentity))
    }
}
