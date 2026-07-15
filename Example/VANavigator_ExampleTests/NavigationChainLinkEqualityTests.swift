//
//  NavigationChainLinkEqualityTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 24.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Testing
import UIKit
import VANavigator

@Suite(.serialized)
final class NavigationChainLinkEqualityTests {
    @Test
    func `Chain links compare by value`() async {
        let expected = NavigationChainLink(
            destination: .identity(MockControllerNavigationIdentity()),
            strategy: .push(),
            animated: true
        )
        let expectedToFail = NavigationChainLink(
            destination: .identity(MockControllerNavigationIdentity()),
            strategy: .push(),
            animated: false
        )
        let expectedToFail1 = NavigationChainLink(
            destination: .identity(MockControllerNavigationIdentity()),
            strategy: .closeToExisting,
            animated: true
        )
        let expectedToFail2 = NavigationChainLink(
            destination: .identity(MockPopControllerNavigationIdentity()),
            strategy: .push(),
            animated: true
        )
        let sut = NavigationChainLink(
            destination: .identity(MockControllerNavigationIdentity()),
            strategy: .push(),
            animated: true
        )

        #expect(expected.isEqual(to: sut))
        #expect(!(expectedToFail.isEqual(to: sut)))
        #expect(!(expectedToFail1.isEqual(to: sut)))
        #expect(!(expectedToFail2.isEqual(to: sut)))
        #expect(!(expected.isEqual(to: nil)))
    }

    @Test
    func `Chain link equality includes fallback`() async {
        let expected = NavigationChainLink(
            destination: .identity(MockControllerNavigationIdentity()),
            strategy: .push(),
            animated: true,
            fallback: NavigationChainLink(
                destination: .identity(MockControllerNavigationIdentity()),
                strategy: .present(),
                animated: true
            )
        )
        let expectedToFail = NavigationChainLink(
            destination: .identity(MockControllerNavigationIdentity()),
            strategy: .push(),
            animated: true,
            fallback: nil
        )
        let expectedToFail1 = NavigationChainLink(
            destination: .identity(MockControllerNavigationIdentity()),
            strategy: .push(),
            animated: true,
            fallback: NavigationChainLink(
                destination: .identity(MockControllerNavigationIdentity()),
                strategy: .closeToExisting,
                animated: true
            )
        )
        let sut = NavigationChainLink(
            destination: .identity(MockControllerNavigationIdentity()),
            strategy: .push(),
            animated: true,
            fallback: NavigationChainLink(
                destination: .identity(MockControllerNavigationIdentity()),
                strategy: .present(),
                animated: true
            )
        )

        #expect(expected.isEqual(to: sut))
        #expect(!(expectedToFail.isEqual(to: sut)))
        #expect(!(expectedToFail1.isEqual(to: sut)))
        #expect(!(expected.isEqual(to: nil)))
    }
}
