//
//  QueueTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 23.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import XCTest
import VANavigator

// TODO: - Messages
@MainActor
class QueueTests: XCTestCase {
    var window: UIWindow?

    override func setUp() {
        window = UIWindow()
    }

    override func tearDown() {
        window = nil
    }

    func test_navigationWithoutDelay_queue() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigation(navigator: navigator)
        let expectedIdentity = MockRootControllerNavigationIdentity()
        let identity = MockPopControllerNavigationIdentity()

        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.rootViewController?.navigationIdentity))

        let expect1 = expectation(description: "navigation.present1")
        let expect2 = expectation(description: "navigation.dismiss1")
        let expect3 = expectation(description: "navigation.present2")
        let expect4 = expectation(description: "navigation.dismiss2")
        let expect5 = expectation(description: "navigation.present3")
        let expect6 = expectation(description: "navigation.dismiss3")
        let expect7 = expectation(description: "navigation.present4")
        let expect8 = expectation(description: "navigation.dismiss4")
        navigator.navigate(
            destination: .identity(identity),
            strategy: .present(),
            completion: { _, _ in taskDetachedMain { expect1.fulfill() } }
        )
        navigator.navigate(
            destination: .identity(identity),
            strategy: .closeIfTop(),
            completion: { _, _ in taskDetachedMain { expect2.fulfill() } }
        )
        navigator.navigate(
            destination: .identity(identity),
            strategy: .present(),
            completion: { _, _ in taskDetachedMain { expect3.fulfill() } }
        )
        navigator.navigate(
            destination: .identity(identity),
            strategy: .closeIfTop(),
            completion: { _, _ in taskDetachedMain { expect4.fulfill() } }
        )
        navigator.navigate(
            destination: .identity(identity),
            strategy: .present(),
            completion: { _, _ in taskDetachedMain { expect5.fulfill() } }
        )
        navigator.navigate(
            destination: .identity(identity),
            strategy: .closeIfTop(),
            completion: { _, _ in taskDetachedMain { expect6.fulfill() } }
        )
        navigator.navigate(
            destination: .identity(identity),
            strategy: .present(),
            completion: { _, _ in taskDetachedMain { expect7.fulfill() } }
        )
        navigator.navigate(
            destination: .identity(identity),
            strategy: .closeIfTop(),
            completion: { _, _ in taskDetachedMain { expect8.fulfill() } }
        )

        wait(for: [expect1, expect2, expect3, expect4, expect5, expect6, expect7, expect8], timeout: 10)

        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.rootViewController?.navigationIdentity))
    }

    func test_navigationChainWithoutDelay_queue() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigation(navigator: navigator)
        let expectedIdentity = MockRootControllerNavigationIdentity()
        let identity = MockPopControllerNavigationIdentity()

        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.rootViewController?.navigationIdentity))

        let expect1 = expectation(description: "navigation.present1")
        let expect2 = expectation(description: "navigation.dismiss1")
        let expect3 = expectation(description: "navigation.present2")
        let expect4 = expectation(description: "navigation.dismiss2")
        let expect5 = expectation(description: "navigation.present3")
        let expect6 = expectation(description: "navigation.dismiss3")
        let expect7 = expectation(description: "navigation.present4")
        let expect8 = expectation(description: "navigation.dismiss4")
        navigator.navigate(
            chain: [.init(destination: .identity(identity), strategy: .present(), animated: true)],
            completion: { _, _ in taskDetachedMain { expect1.fulfill() } }
        )
        navigator.navigate(
            chain: [.init(destination: .identity(identity), strategy: .closeIfTop(), animated: true)],
            completion: { _, _ in taskDetachedMain { expect2.fulfill() } }
        )
        navigator.navigate(
            chain: [.init(destination: .identity(identity), strategy: .present(), animated: true)],
            completion: { _, _ in taskDetachedMain { expect3.fulfill() } }
        )
        navigator.navigate(
            chain: [.init(destination: .identity(identity), strategy: .closeIfTop(), animated: true)],
            completion: { _, _ in taskDetachedMain { expect4.fulfill() } }
        )
        navigator.navigate(
            chain: [.init(destination: .identity(identity), strategy: .present(), animated: true)],
            completion: { _, _ in taskDetachedMain { expect5.fulfill() } }
        )
        navigator.navigate(
            chain: [.init(destination: .identity(identity), strategy: .closeIfTop(), animated: true)],
            completion: { _, _ in taskDetachedMain { expect6.fulfill() } }
        )
        navigator.navigate(
            chain: [],
            completion: { _, _ in taskDetachedMain { expect7.fulfill() } }
        )
        navigator.navigate(
            chain: [],
            completion: { _, _ in taskDetachedMain { expect8.fulfill() } }
        )

        wait(for: [expect1, expect2, expect3, expect4, expect5, expect6, expect7, expect8], timeout: 10)

        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.rootViewController?.navigationIdentity))
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
