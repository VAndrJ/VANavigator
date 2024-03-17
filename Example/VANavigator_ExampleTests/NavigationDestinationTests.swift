//
//  NavigationDestinationTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 17.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import XCTest
import VANavigator
import VATextureKit

class NavigationDestinationTests: XCTestCase, MainActorIsolated {

    func test_identity_equality() {
        let identity = MockRootControllerNavigationIdentity()

        XCTAssertTrue(identity.isEqual(to: NavigationDestination.identity(MockRootControllerNavigationIdentity()).identity))
        XCTAssertFalse(identity.isEqual(to: NavigationDestination.identity(MockPopControllerNavigationIdentity()).identity))
    }

    func test_controllersIdentity_equality() {
        let identity = MockRootControllerNavigationIdentity()

        let controller = UIViewController()
        controller.navigationIdentity = MockRootControllerNavigationIdentity()
        let destination: NavigationDestination = .controller(controller)
        XCTAssertTrue(identity.isEqual(to: destination.identity))

        let controllerToFail = UIViewController()
        controllerToFail.navigationIdentity = MockPopControllerNavigationIdentity()
        let destinationToFail: NavigationDestination = .controller(controllerToFail)
        XCTAssertFalse(identity.isEqual(to: destinationToFail.identity))
    }
}
