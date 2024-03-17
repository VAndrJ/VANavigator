//
//  SearchTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 23.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import XCTest
import VANavigator
@testable import VANavigator_Example
import VATextureKit

// TODO: - Messages
class SearchTests: XCTestCase, MainActorIsolated {
    var window: UIWindow?

    override func setUp() {
        window = UIWindow()
    }

    override func tearDown() {
        window = nil
    }

    // swiftlint:disable force_unwrapping
    func test_tabSearch() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let primaryIdentity = MockControllerNavigationIdentity()
        let secondaryIdentity = LoginNavigationIdentity()
        let splitIdentity = MockSplitControllerNavigationIdentity(
            primary: primaryIdentity,
            secondary: secondaryIdentity
        )
        let identity = MockRootControllerNavigationIdentity()
        let identity1 = MockPushControllerNavigationIdentity()
        let navIdentity = MockNavControllerNavigationIdentity(children: [identity, identity1])
        let tabIdentity = MockTabControllerNavigationIdentity(children: [navIdentity])
        let presentIdentity = MockPopControllerNavigationIdentity()

        let expect = expectation(description: "navigation.replaceWindowRoot")
        navigator.navigate(
            chain: [
                .init(destination: .identity(splitIdentity), strategy: .replaceWindowRoot(), animated: false),
                .init(destination: .identity(tabIdentity), strategy: .present(source: .navigationController), animated: false),
                .init(destination: .identity(presentIdentity), strategy: .present(), animated: true),
            ],
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)

        let controller = window?.findController(destination: .identity(identity))
        XCTAssertTrue(identity.isEqual(to: controller?.navigationIdentity))
        XCTAssertEqual(controller, window?.findController(destination: .controller(controller!)))
        let controller1 = window?.findController(destination: .identity(identity1))
        XCTAssertTrue(identity1.isEqual(to: controller1?.navigationIdentity))
        XCTAssertEqual(controller1, window?.findController(destination: .controller(controller1!)))
        let navController = window?.findController(destination: .identity(navIdentity))
        XCTAssertTrue(navIdentity.isEqual(to: navController?.navigationIdentity))
        XCTAssertEqual(navController, window?.findController(destination: .controller(navController!)))
        let tabController = window?.findController(destination: .identity(tabIdentity))
        XCTAssertTrue(tabIdentity.isEqual(to: tabController?.navigationIdentity))
        XCTAssertEqual(tabController, window?.findController(destination: .controller(tabController!)))
        let presentedController = window?.findController(destination: .identity(presentIdentity))
        XCTAssertTrue(presentIdentity.isEqual(to: presentedController?.navigationIdentity))
        XCTAssertEqual(presentedController, window?.findController(destination: .controller(presentedController!)))
        let splitController = window?.findController(destination: .identity(splitIdentity))
        XCTAssertTrue(splitIdentity.isEqual(to: splitController?.navigationIdentity))
        XCTAssertEqual(splitController, window?.findController(destination: .controller(splitController!)))
        let primaryController = window?.findController(destination: .identity(primaryIdentity))
        XCTAssertTrue(primaryIdentity.isEqual(to: primaryController?.navigationIdentity))
        XCTAssertEqual(primaryController, window?.findController(destination: .controller(primaryController!)))
        let secondaryController = window?.findController(destination: .identity(secondaryIdentity))
        XCTAssertTrue(secondaryIdentity.isEqual(to: secondaryController?.navigationIdentity))
        XCTAssertEqual(secondaryController, window?.findController(destination: .controller(secondaryController!)))

        XCTAssertEqual(presentedController, window?.topController)
        XCTAssertEqual(tabController, controller?.findTabBarController())
        XCTAssertEqual(tabController, controller1?.findTabBarController())
        XCTAssertEqual(tabController, navController?.findTabBarController())
        XCTAssertEqual(tabController, tabController?.findTabBarController())
        XCTAssertEqual(tabController, presentedController?.findTabBarController())
        XCTAssertNil(splitController?.findTabBarController())
    }
    // swiftlint:enable force_unwrapping
}
