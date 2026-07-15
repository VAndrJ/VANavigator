//
//  NavigationStrategyEqualityTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 20.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit
import VANavigator
import XCTest

class NavigationStrategyEqualityTests: XCTestCase {
    func test_push() async {
        let expected: NavigationStrategy = .push()
        let expectedToFail: NavigationStrategy = .popToExisting()
        let sut: NavigationStrategy = .push()

        XCTAssertEqual(expected, sut)
        XCTAssertNotEqual(expectedToFail, sut)
    }

    func test_pushWithConfigurationClosure_comparesByInstance() async {
        let expected: NavigationStrategy = .push(navigation: { _ in })
        let sut: NavigationStrategy = .push(navigation: { _ in })

        XCTAssertNotEqual(expected, sut)
        XCTAssertEqual(expected, expected)
    }

    func test_popover_comparesByInstance() async {
        let expected: NavigationStrategy = .popover(configure: { _, _ in })
        let sut: NavigationStrategy = .popover(configure: { _, _ in })

        XCTAssertNotEqual(expected, sut)
        XCTAssertEqual(expected, expected)
    }

    func test_pop() async {
        let expected: NavigationStrategy = .popToExisting()
        let expectedToFail: NavigationStrategy = .popToExisting(includingTabs: false)
        let expectedToFail1: NavigationStrategy = .present()
        let sut: NavigationStrategy = .popToExisting()

        XCTAssertEqual(expected, sut)
        XCTAssertNotEqual(expectedToFail, sut)
        XCTAssertNotEqual(expectedToFail1, sut)
    }

    func test_replaceNavigationRoot() async {
        let expected: NavigationStrategy = .replaceNavigationRoot
        let expectedToFail: NavigationStrategy = .replaceWindowRoot()
        let sut: NavigationStrategy = .replaceNavigationRoot

        XCTAssertEqual(expected, sut)
        XCTAssertNotEqual(expectedToFail, sut)
    }

    func test_present() async {
        let expected: NavigationStrategy = .present()
        let expectedToFail: NavigationStrategy = .present(source: .navigationController)
        let expectedToFail1: NavigationStrategy = .present(source: .tabBarController)
        let expectedToFail2: NavigationStrategy = .replaceNavigationRoot
        let sut: NavigationStrategy = .present()

        XCTAssertEqual(expected, sut)
        XCTAssertNotEqual(expectedToFail, sut)
        XCTAssertNotEqual(expectedToFail1, sut)
        XCTAssertNotEqual(expectedToFail2, sut)
    }

    func test_replaceWindowRoot() async {
        let expected: NavigationStrategy = .replaceWindowRoot()
        let expectedToFail: NavigationStrategy = .replaceWindowRoot(transition: CATransition())
        let expectedToFail1: NavigationStrategy = .closeToExisting
        let sut: NavigationStrategy = .replaceWindowRoot()

        XCTAssertEqual(expected, sut)
        XCTAssertNotEqual(expectedToFail, sut)
        XCTAssertNotEqual(expectedToFail1, sut)
    }

    func test_closeToExisting() async {
        let expected: NavigationStrategy = .closeToExisting
        let expectedToFail: NavigationStrategy = .closeIfTop()
        let sut: NavigationStrategy = .closeToExisting

        XCTAssertEqual(expected, sut)
        XCTAssertNotEqual(expectedToFail, sut)
    }

    func test_closeIfTop() async {
        let expected: NavigationStrategy = .closeIfTop()
        let expectedToFail: NavigationStrategy = .closeIfTop(tryToPop: false, tryToDismiss: true)
        let expectedToFail1: NavigationStrategy = .closeIfTop(tryToPop: false, tryToDismiss: false)
        let expectedToFail2: NavigationStrategy = .closeIfTop(tryToPop: true, tryToDismiss: false)
        let expectedToFail3: NavigationStrategy = .split(strategy: .primary(action: .pop))
        let sut: NavigationStrategy = .closeIfTop()

        XCTAssertEqual(expected, sut)
        XCTAssertNotEqual(expectedToFail, sut)
        XCTAssertNotEqual(expectedToFail1, sut)
        XCTAssertNotEqual(expectedToFail2, sut)
        XCTAssertNotEqual(expectedToFail3, sut)
    }

    func test_closeIfTopWithNavigationClosure_comparesByInstance() async {
        let expected: NavigationStrategy = .closeIfTop(navigation: { _ in })
        let sut: NavigationStrategy = .closeIfTop(navigation: { _ in })

        XCTAssertNotEqual(expected, sut)
        XCTAssertEqual(expected, expected)
    }

    func test_split() async {
        let expected: NavigationStrategy = .split(strategy: .primary(action: .push))
        let expectedToFail: NavigationStrategy = .split(strategy: .primary(action: .pop))
        let expectedToFail1: NavigationStrategy = .split(strategy: .secondary(action: .push))
        let expectedToFail2: NavigationStrategy = .split(strategy: .secondary(action: .pop))
        let expectedToFail3: NavigationStrategy = .push()
        let sut: NavigationStrategy = .split(strategy: .primary(action: .push))

        XCTAssertEqual(expected, sut)
        XCTAssertNotEqual(expectedToFail, sut)
        XCTAssertNotEqual(expectedToFail1, sut)
        XCTAssertNotEqual(expectedToFail2, sut)
        XCTAssertNotEqual(expectedToFail3, sut)
    }
}
