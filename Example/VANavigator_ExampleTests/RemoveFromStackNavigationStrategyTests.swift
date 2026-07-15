//
//  RemoveFromStackNavigationStrategyTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 01.03.2024.
//  Copyright © 2024 Volodymyr Andriienko. All rights reserved.
//

import Testing
import UIKit
import VANavigator

@Suite(.serialized)
final class RemoveFromStackNavigationStrategyTests {
    let window: UIWindow? = UIWindow()

    @Test
    func `Removing the only controller fails`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let childIdentity = MockRootControllerNavigationIdentity()
        let identity = MockNavControllerNavigationIdentity(children: [
            childIdentity
        ])
        await prepareNavigationStack(navigator: navigator, identity: identity)
        let rootNavigationController = window?.rootViewController as? UINavigationController

        #expect(rootNavigationController?.viewControllers.count == 1)
        #expect(childIdentity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity))

        let expect = expectation(description: "removeFromStack")
        var result: Bool?
        navigator.navigate(
            destination: .identity(childIdentity),
            strategy: .removeFromNavigationStack,
            event: ResponderMockEvent(),
            completion: { _, isSuccess in
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((false) == (result))
        #expect(rootNavigationController?.viewControllers.count == 1)
        #expect(childIdentity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity))
    }

    @Test
    func `Removing the only controller uses fallback`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let childIdentity = MockRootControllerNavigationIdentity()
        await prepareNavigationStack(navigator: navigator, identity: childIdentity)
        let expectedIdentity = MockPushControllerNavigationIdentity()

        #expect(childIdentity.isEqual(to: window?.rootViewController?.navigationIdentity))

        let expect = expectation(description: "removeFromStack")
        var result: Bool?
        navigator.navigate(
            destination: .identity(childIdentity),
            strategy: .removeFromNavigationStack,
            fallback: .init(
                destination: .identity(expectedIdentity),
                strategy: .replaceWindowRoot(),
                animated: false
            ),
            event: ResponderMockEvent(),
            completion: { _, isSuccess in
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((true) == (result))
        #expect(expectedIdentity.isEqual(to: window?.rootViewController?.navigationIdentity))
    }

    @Test
    func `Removes a matching controller from a navigation stack`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let childIdentity = MockRootControllerNavigationIdentity()
        let expectedIdentity = MockPushControllerNavigationIdentity()
        let identity = MockNavControllerNavigationIdentity(children: [
            childIdentity,
            expectedIdentity,
        ])
        await prepareNavigationStack(navigator: navigator, identity: identity)
        let rootNavigationController = window?.rootViewController as? UINavigationController

        #expect(rootNavigationController?.viewControllers.count == 2)
        #expect(expectedIdentity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity))

        let expect = expectation(description: "removeFromStack")
        var result: Bool?
        navigator.navigate(
            destination: .identity(childIdentity),
            strategy: .removeFromNavigationStack,
            event: ResponderMockEvent(),
            completion: { _, isSuccess in
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((true) == (result))
        #expect(rootNavigationController?.viewControllers.count == 1)
        #expect(expectedIdentity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity))
        #expect(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    @Test
    func `Controller destination without identity removes exact instance`() async {
        let rootController = UIViewController()
        let controllerToRemove = UIViewController()
        let topController = UIViewController()
        let navigationController = UINavigationController()
        navigationController.viewControllers = [rootController, controllerToRemove, topController]
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let expect = expectation(description: "remove exact controller")
        var result: Bool?

        navigator.navigate(
            destination: .controller(controllerToRemove),
            strategy: .removeFromNavigationStack,
            animated: false,
            completion: { _, isSuccess in
                result = isSuccess
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((true) == (result))
        #expect((2) == (navigationController.viewControllers.count))
        #expect((rootController) === (navigationController.viewControllers.first))
        #expect((topController) === (navigationController.topViewController))
        #expect(!(navigationController.viewControllers.contains { $0 === controllerToRemove }))
    }

    func prepareNavigationStack(navigator: Navigator, identity: any NavigationIdentity) async {
        let expect = expectation(description: "navigation.replaceWindowRoot")
        navigator.navigate(
            destination: .identity(identity),
            strategy: .replaceWindowRoot(),
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        await fulfillment(of: [expect], timeout: 10)
    }
}
