//
//  NavigationDestinationEqualityTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 20.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import XCTest
import VANavigator
import VATextureKit

class NavigationDestinationEqualityTests: XCTestCase, MainActorIsolated {

    func test_identity_identity() {
        let expected: NavigationDestination = .identity(MockRootControllerNavigationIdentity())
        let expectedToFail: NavigationDestination = .identity(MockPopControllerNavigationIdentity())
        let sut: NavigationDestination = .identity(MockRootControllerNavigationIdentity())

        XCTAssertTrue(expected.isEqual(to: sut))
        XCTAssertFalse(expectedToFail.isEqual(to: sut))
        XCTAssertFalse(expected.isEqual(to: nil))
    }

    func test_identity_controller() {
        let controller = UIViewController()
        controller.navigationIdentity = MockRootControllerNavigationIdentity()
        let expected: NavigationDestination = .controller(controller)
        let expectedToFail: NavigationDestination = .identity(MockPopControllerNavigationIdentity())
        let controller1 = UIViewController()
        controller1.navigationIdentity = MockPopControllerNavigationIdentity()
        let expectedToFail1: NavigationDestination = .controller(controller1)
        let sut: NavigationDestination = .identity(MockRootControllerNavigationIdentity())

        XCTAssertTrue(expected.isEqual(to: sut))
        XCTAssertFalse(expectedToFail.isEqual(to: sut))
        XCTAssertFalse(expectedToFail1.isEqual(to: sut))
        XCTAssertFalse(expected.isEqual(to: nil))
    }

    func test_controller_controller() {
        let controller = UIViewController()
        controller.navigationIdentity = MockRootControllerNavigationIdentity()
        let expected: NavigationDestination = .controller(controller)
        let expectedToFail: NavigationDestination = .identity(MockPopControllerNavigationIdentity())
        let controller1 = UIViewController()
        controller1.navigationIdentity = MockPopControllerNavigationIdentity()
        let expectedToFail1: NavigationDestination = .controller(controller1)
        let sut: NavigationDestination = .controller(controller)

        XCTAssertTrue(expected.isEqual(to: sut))
        XCTAssertFalse(expectedToFail.isEqual(to: sut))
        XCTAssertFalse(expectedToFail1.isEqual(to: sut))
        XCTAssertFalse(expected.isEqual(to: nil))
    }

    func test_controller_identity() {
        let controller = UIViewController()
        controller.navigationIdentity = MockRootControllerNavigationIdentity()
        let expected: NavigationDestination = .identity(MockRootControllerNavigationIdentity())
        let expectedToFail: NavigationDestination = .identity(MockPopControllerNavigationIdentity())
        let controller1 = UIViewController()
        controller1.navigationIdentity = MockPopControllerNavigationIdentity()
        let expectedToFail1: NavigationDestination = .controller(controller1)
        let sut: NavigationDestination = .controller(controller)

        XCTAssertTrue(expected.isEqual(to: sut))
        XCTAssertFalse(expectedToFail.isEqual(to: sut))
        XCTAssertFalse(expectedToFail1.isEqual(to: sut))
        XCTAssertFalse(expected.isEqual(to: nil))
    }
}
