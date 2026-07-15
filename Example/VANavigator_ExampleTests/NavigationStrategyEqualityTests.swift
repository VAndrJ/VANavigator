//
//  NavigationStrategyEqualityTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 20.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Testing
import UIKit
import VANavigator

@Suite(.serialized)
final class NavigationStrategyEqualityTests {
    @Test
    func `Push strategies compare by value`() async {
        let expected: NavigationStrategy = .push()
        let expectedToFail: NavigationStrategy = .popToExisting()
        let sut: NavigationStrategy = .push()

        #expect((expected) == (sut))
        #expect((expectedToFail) != (sut))
    }

    @Test
    func `Push strategies with configuration closures compare by instance`() async {
        let expected: NavigationStrategy = .push(navigation: { _ in })
        let sut: NavigationStrategy = .push(navigation: { _ in })

        #expect((expected) != (sut))
        #expect((expected) == (expected))
    }

    @Test
    func `Popover strategies compare by instance`() async {
        let expected: NavigationStrategy = .popover(configure: { _, _ in })
        let sut: NavigationStrategy = .popover(configure: { _, _ in })

        #expect((expected) != (sut))
        #expect((expected) == (expected))
    }

    @Test
    func `Pop strategies compare by value`() async {
        let expected: NavigationStrategy = .popToExisting()
        let expectedToFail: NavigationStrategy = .popToExisting(includingTabs: false)
        let expectedToFail1: NavigationStrategy = .present()
        let sut: NavigationStrategy = .popToExisting()

        #expect((expected) == (sut))
        #expect((expectedToFail) != (sut))
        #expect((expectedToFail1) != (sut))
    }

    @Test
    func `Navigation root replacement strategies compare by value`() async {
        let expected: NavigationStrategy = .replaceNavigationRoot
        let expectedToFail: NavigationStrategy = .replaceWindowRoot()
        let sut: NavigationStrategy = .replaceNavigationRoot

        #expect((expected) == (sut))
        #expect((expectedToFail) != (sut))
    }

    @Test
    func `Presentation strategies compare by value`() async {
        let expected: NavigationStrategy = .present()
        let expectedToFail: NavigationStrategy = .present(source: .navigationController)
        let expectedToFail1: NavigationStrategy = .present(source: .tabBarController)
        let expectedToFail2: NavigationStrategy = .replaceNavigationRoot
        let sut: NavigationStrategy = .present()

        #expect((expected) == (sut))
        #expect((expectedToFail) != (sut))
        #expect((expectedToFail1) != (sut))
        #expect((expectedToFail2) != (sut))
    }

    @Test
    func `Window root replacement strategies compare by value`() async {
        let expected: NavigationStrategy = .replaceWindowRoot()
        let expectedToFail: NavigationStrategy = .replaceWindowRoot(transition: CATransition())
        let expectedToFail1: NavigationStrategy = .closeToExisting
        let sut: NavigationStrategy = .replaceWindowRoot()

        #expect((expected) == (sut))
        #expect((expectedToFail) != (sut))
        #expect((expectedToFail1) != (sut))
    }

    @Test
    func `Close to existing strategies compare by value`() async {
        let expected: NavigationStrategy = .closeToExisting
        let expectedToFail: NavigationStrategy = .closeIfTop()
        let sut: NavigationStrategy = .closeToExisting

        #expect((expected) == (sut))
        #expect((expectedToFail) != (sut))
    }

    @Test
    func `Close if top strategies compare by value`() async {
        let expected: NavigationStrategy = .closeIfTop()
        let expectedToFail: NavigationStrategy = .closeIfTop(tryToPop: false, tryToDismiss: true)
        let expectedToFail1: NavigationStrategy = .closeIfTop(tryToPop: false, tryToDismiss: false)
        let expectedToFail2: NavigationStrategy = .closeIfTop(tryToPop: true, tryToDismiss: false)
        let expectedToFail3: NavigationStrategy = .split(strategy: .primary(action: .pop))
        let sut: NavigationStrategy = .closeIfTop()

        #expect((expected) == (sut))
        #expect((expectedToFail) != (sut))
        #expect((expectedToFail1) != (sut))
        #expect((expectedToFail2) != (sut))
        #expect((expectedToFail3) != (sut))
    }

    @Test
    func `Close if top strategies with navigation closures compare by instance`() async {
        let expected: NavigationStrategy = .closeIfTop(navigation: { _ in })
        let sut: NavigationStrategy = .closeIfTop(navigation: { _ in })

        #expect((expected) != (sut))
        #expect((expected) == (expected))
    }

    @Test
    func `Split strategies compare by value`() async {
        let expected: NavigationStrategy = .split(strategy: .primary(action: .push))
        let expectedToFail: NavigationStrategy = .split(strategy: .primary(action: .pop))
        let expectedToFail1: NavigationStrategy = .split(strategy: .secondary(action: .push))
        let expectedToFail2: NavigationStrategy = .split(strategy: .secondary(action: .pop))
        let expectedToFail3: NavigationStrategy = .push()
        let sut: NavigationStrategy = .split(strategy: .primary(action: .push))

        #expect((expected) == (sut))
        #expect((expectedToFail) != (sut))
        #expect((expectedToFail1) != (sut))
        #expect((expectedToFail2) != (sut))
        #expect((expectedToFail3) != (sut))
    }
}
