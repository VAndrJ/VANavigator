//
//  NavigationChainLinkEqualityTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 24.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import XCTest
import VANavigator

@MainActor
class NavigationChainLinkEqualityTests: XCTestCase {

    func test_links() {
        let expected = NavigationChainLink(
            destination: .identity(MockControllerNavigationIdentity()),
            strategy: .push,
            animated: true
        )
        let expectedToFail = NavigationChainLink(
            destination: .identity(MockControllerNavigationIdentity()),
            strategy: .push,
            animated: false
        )
        let expectedToFail1 = NavigationChainLink(
            destination: .identity(MockControllerNavigationIdentity()),
            strategy: .closeToExisting,
            animated: true
        )
        let expectedToFail2 = NavigationChainLink(
            destination: .identity(MockPopControllerNavigationIdentity()),
            strategy: .push,
            animated: true
        )
        let sut = NavigationChainLink(
            destination: .identity(MockControllerNavigationIdentity()),
            strategy: .push,
            animated: true
        )

        XCTAssertTrue(expected.isEqual(to: sut))
        XCTAssertFalse(expectedToFail.isEqual(to: sut))
        XCTAssertFalse(expectedToFail1.isEqual(to: sut))
        XCTAssertFalse(expectedToFail2.isEqual(to: sut))
        XCTAssertFalse(expected.isEqual(to: nil))
    }

    func test_links_fallback() {
        let expected = NavigationChainLink(
            destination: .identity(MockControllerNavigationIdentity()),
            strategy: .push,
            animated: true,
            fallback: NavigationChainLink(
                destination: .identity(MockControllerNavigationIdentity()),
                strategy: .present(),
                animated: true
            )
        )
        let expectedToFail = NavigationChainLink(
            destination: .identity(MockControllerNavigationIdentity()),
            strategy: .push,
            animated: true,
            fallback: nil
        )
        let expectedToFail1 = NavigationChainLink(
            destination: .identity(MockControllerNavigationIdentity()),
            strategy: .push,
            animated: true,
            fallback: NavigationChainLink(
                destination: .identity(MockControllerNavigationIdentity()),
                strategy: .closeToExisting,
                animated: true
            )
        )
        let sut = NavigationChainLink(
            destination: .identity(MockControllerNavigationIdentity()),
            strategy: .push,
            animated: true,
            fallback: NavigationChainLink(
                destination: .identity(MockControllerNavigationIdentity()),
                strategy: .present(),
                animated: true
            )
        )

        XCTAssertTrue(expected.isEqual(to: sut))
        XCTAssertFalse(expectedToFail.isEqual(to: sut))
        XCTAssertFalse(expectedToFail1.isEqual(to: sut))
        XCTAssertFalse(expected.isEqual(to: nil))
    }
}
