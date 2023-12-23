//
//  NavigationDestinationEqualityTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 20.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import XCTest
import VANavigator

@MainActor
class NavigationDestinationEqualityTests: XCTestCase {

    func test_identity_identity() {
        let expected: NavigationDestination = .identity(MockRootControllerNavigationIdentity())
        let expectedToFail: NavigationDestination = .identity(MockPopControllerNavigationIdentity())
        let sut: NavigationDestination = .identity(MockRootControllerNavigationIdentity())

        XCTAssertEqual(true, expected.isEqual(to: sut))
        XCTAssertEqual(false, expectedToFail.isEqual(to: sut))
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

        XCTAssertEqual(true, expected.isEqual(to: sut))
        XCTAssertEqual(false, expectedToFail.isEqual(to: sut))
        XCTAssertEqual(false, expectedToFail1.isEqual(to: sut))
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

        XCTAssertEqual(true, expected.isEqual(to: sut))
        XCTAssertEqual(false, expectedToFail.isEqual(to: sut))
        XCTAssertEqual(false, expectedToFail1.isEqual(to: sut))
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

        XCTAssertEqual(true, expected.isEqual(to: sut))
        XCTAssertEqual(false, expectedToFail.isEqual(to: sut))
        XCTAssertEqual(false, expectedToFail1.isEqual(to: sut))
    }
}
