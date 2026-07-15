//
//  NavigationDestinationEqualityTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 20.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Testing
import UIKit
import VANavigator

@testable import VANavigator_Example

@Suite(.serialized)
final class NavigationDestinationEqualityTests {
    @Test
    func `Identity destinations compare equally`() async {
        let expected: NavigationDestination = .identity(MockRootControllerNavigationIdentity())
        let expectedToFail: NavigationDestination = .identity(MockPopControllerNavigationIdentity())
        let sut: NavigationDestination = .identity(MockRootControllerNavigationIdentity())

        #expect(expected.isEqual(to: sut))
        #expect(!(expectedToFail.isEqual(to: sut)))
        #expect(!(expected.isEqual(to: nil)))
    }

    @Test
    func `Identity and controller destinations compare equally`() async {
        let controller = UIViewController()
        controller.navigationIdentity = MockRootControllerNavigationIdentity()
        let expected: NavigationDestination = .controller(controller)
        let expectedToFail: NavigationDestination = .identity(MockPopControllerNavigationIdentity())
        let controller1 = UIViewController()
        controller1.navigationIdentity = MockPopControllerNavigationIdentity()
        let expectedToFail1: NavigationDestination = .controller(controller1)
        let sut: NavigationDestination = .identity(MockRootControllerNavigationIdentity())

        #expect(expected.isEqual(to: sut))
        #expect(!(expectedToFail.isEqual(to: sut)))
        #expect(!(expectedToFail1.isEqual(to: sut)))
        #expect(!(expected.isEqual(to: nil)))
    }

    @Test
    func `Controller destinations compare equally`() async {
        let controller = UIViewController()
        controller.navigationIdentity = MockRootControllerNavigationIdentity()
        let expected: NavigationDestination = .controller(controller)
        let expectedToFail: NavigationDestination = .identity(MockPopControllerNavigationIdentity())
        let controller1 = UIViewController()
        controller1.navigationIdentity = MockPopControllerNavigationIdentity()
        let expectedToFail1: NavigationDestination = .controller(controller1)
        let sut: NavigationDestination = .controller(controller)

        #expect(expected.isEqual(to: sut))
        #expect(!(expectedToFail.isEqual(to: sut)))
        #expect(!(expectedToFail1.isEqual(to: sut)))
        #expect(!(expected.isEqual(to: nil)))
    }

    @Test
    func `Controller and identity destinations compare equally`() async {
        let controller = UIViewController()
        controller.navigationIdentity = MockRootControllerNavigationIdentity()
        let expected: NavigationDestination = .identity(MockRootControllerNavigationIdentity())
        let expectedToFail: NavigationDestination = .identity(MockPopControllerNavigationIdentity())
        let controller1 = UIViewController()
        controller1.navigationIdentity = MockPopControllerNavigationIdentity()
        let expectedToFail1: NavigationDestination = .controller(controller1)
        let sut: NavigationDestination = .controller(controller)

        #expect(expected.isEqual(to: sut))
        #expect(!(expectedToFail.isEqual(to: sut)))
        #expect(!(expectedToFail1.isEqual(to: sut)))
        #expect(!(expected.isEqual(to: nil)))
    }

    @Test
    func `Split identity equality includes optional supplementary identity`() async {
        let sut = SplitNavigationIdentity(
            primary: PrimaryNavigationIdentity(),
            secondary: SecondaryNavigationIdentity(),
            supplementary: nil
        )
        let expected = SplitNavigationIdentity(
            primary: PrimaryNavigationIdentity(),
            secondary: SecondaryNavigationIdentity(),
            supplementary: nil
        )
        let expectedToFail = SplitNavigationIdentity(
            primary: PrimaryNavigationIdentity(),
            secondary: SecondaryNavigationIdentity(),
            supplementary: MoreNavigationIdentity()
        )

        #expect(sut.isEqual(to: expected))
        #expect(!(sut.isEqual(to: expectedToFail)))
    }
}
