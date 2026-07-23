//
//  ReplaceNavigationRootControllerTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 15.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Testing
import UIKit
import VANavigator

// TODO: - Messages
@Suite(.serialized)
final class ReplaceNavigationRootControllerTests {
    let window: UIWindow? = UIWindow()

    @Test
    func `Replaces navigation root controller`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationStack(navigator: navigator)
        let newRootIdentity = MockPushControllerNavigationIdentity()
        let navigationController = window?.rootViewController as? UINavigationController

        #expect((navigationController) != nil)
        #expect((2) == (navigationController?.viewControllers.count))
        #expect(!(newRootIdentity.isEqual(to: navigationController?.viewControllers.first?.navigationIdentity)))

        let expect = expectation(description: "replace")
        var responder: UIViewController?
        navigator.navigate(
            destination: .identity(newRootIdentity),
            strategy: .replaceNavigationRoot,
            event: ResponderMockEvent(),
            completion: { controller, _ in
                responder = controller
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((1) == (navigationController?.viewControllers.count))
        #expect(newRootIdentity.isEqual(to: navigationController?.viewControllers.first?.navigationIdentity))
        #expect((true) == ((responder as? MockViewController)?.isMockEventHandled))
    }

    @Test
    func `Navigation root replacement uses fallback`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigation(navigator: navigator)
        let newRootIdentity = MockPushControllerNavigationIdentity()

        #expect((window?.rootViewController as? UINavigationController) == nil)
        #expect(!(newRootIdentity.isEqual(to: window?.rootViewController?.navigationIdentity)))

        let expect = expectation(description: "replace")
        var responder: UIViewController?
        navigator.navigate(
            destination: .identity(newRootIdentity),
            strategy: .replaceNavigationRoot,
            fallbackStrategies: [.closeToExisting, .present()],
            event: ResponderMockEvent(),
            completion: { controller, _ in
                responder = controller
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect(!(newRootIdentity.isEqual(to: window?.rootViewController?.navigationIdentity)))
        #expect(newRootIdentity.isEqual(to: window?.topController?.navigationIdentity))
        #expect((true) == ((responder as? MockViewController)?.isMockEventHandled))
    }

    @Test
    func `Navigation root replacement fails without fallback`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigation(navigator: navigator)
        let newRootIdentity = MockPushControllerNavigationIdentity()

        #expect((window?.rootViewController as? UINavigationController) == nil)
        #expect(!(newRootIdentity.isEqual(to: window?.rootViewController?.navigationIdentity)))

        let expect = expectation(description: "replace")
        var responder: UIViewController?
        navigator.navigate(
            destination: .identity(newRootIdentity),
            strategy: .replaceNavigationRoot,
            event: ResponderMockEvent(),
            completion: { controller, _ in
                responder = controller
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((window?.rootViewController as? UINavigationController) == nil)
        #expect((responder) == nil)
        #expect(!(newRootIdentity.isEqual(to: window?.rootViewController?.navigationIdentity)))
        #expect(!(newRootIdentity.isEqual(to: window?.topController?.navigationIdentity)))
        #expect(MockRootControllerNavigationIdentity().isEqual(to: window?.rootViewController?.navigationIdentity))
        #expect(MockRootControllerNavigationIdentity().isEqual(to: window?.topController?.navigationIdentity))
    }

    @Test
    func `Navigation root replacement rejects navigation controller destination`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationStack(navigator: navigator)
        let navigationController = window?.rootViewController as? UINavigationController
        let originalControllers = navigationController?.viewControllers
        let nestedNavigationController = UINavigationController(rootViewController: UIViewController())
        let expect = expectation(description: "replace rejected")
        var responder: UIViewController?
        var result: Bool?

        navigator.navigate(
            destination: .controller(nestedNavigationController),
            strategy: .replaceNavigationRoot,
            animated: false,
            completion: {
                responder = $0
                result = $1
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((false) == (result))
        #expect((responder) == nil)
        #expect((originalControllers) == (navigationController?.viewControllers))
        #expect((nestedNavigationController.parent) == nil)
    }

    @Test
    func `Closing presented navigation completes with nil controller`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let expect = expectation(description: "navigation.close")
        navigator.closeNavigationPresented(
            controller: nil,
            animated: true,
            completion: { expect.fulfill() }
        )

        await fulfillment(of: [expect], timeout: 10)
    }

    func prepareNavigation(navigator: Navigator) async {
        let expect = expectation(description: "navigation.replaceWindowRoot")
        navigator.navigate(
            destination: .identity(MockRootControllerNavigationIdentity()),
            strategy: .replaceWindowRoot(),
            completion: { _, _ in expect.fulfill() }
        )

        await fulfillment(of: [expect], timeout: 10)
    }

    func prepareNavigationStack(navigator: Navigator) async {
        let identity = MockNavControllerNavigationIdentity(children: [
            MockRootControllerNavigationIdentity(),
            MockPopControllerNavigationIdentity(),
        ])
        let expect = expectation(description: "navigation.replaceWindowRoot")
        navigator.navigate(
            destination: .identity(identity),
            strategy: .replaceWindowRoot(),
            completion: { _, _ in expect.fulfill() }
        )

        await fulfillment(of: [expect], timeout: 10)
    }
}
