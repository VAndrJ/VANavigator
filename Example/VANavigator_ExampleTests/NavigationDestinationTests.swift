//
//  NavigationDestinationTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 17.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Testing
import UIKit
import VANavigator

@Suite(.serialized)
final class NavigationDestinationTests {
    @Test
    func `Identity equality`() async {
        let identity = MockRootControllerNavigationIdentity()

        #expect(identity.isEqual(to: NavigationDestination.identity(MockRootControllerNavigationIdentity()).identity))
        #expect(!(identity.isEqual(to: NavigationDestination.identity(MockPopControllerNavigationIdentity()).identity)))
    }

    @Test
    func `Controller destination identity equality`() async {
        let identity = MockRootControllerNavigationIdentity()

        let controller = UIViewController()
        controller.navigationIdentity = MockRootControllerNavigationIdentity()
        let destination: NavigationDestination = .controller(controller)
        #expect(identity.isEqual(to: destination.identity))

        let controllerToFail = UIViewController()
        controllerToFail.navigationIdentity = MockPopControllerNavigationIdentity()
        let destinationToFail: NavigationDestination = .controller(controllerToFail)
        #expect(!(identity.isEqual(to: destinationToFail.identity)))
    }
}
