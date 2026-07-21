//
//  PopoverTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 24.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Testing
import UIKit
import VANavigator

// TODO: - Messages
@Suite(.serialized)
final class PopoverTests {
    let window: UIWindow? = UIWindow()

    @Test
    func `Popover navigation succeeds`() async throws {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigation(navigator: navigator)

        #expect(MockRootControllerNavigationIdentity().isEqual(to: window?.rootViewController?.navigationIdentity))

        let identity = MockPushControllerNavigationIdentity()
        let expect = expectation(description: "popover")
        let expect1 = expectation(description: "presentation")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .popover(configure: { popover, controller in
                popover.sourceView = self.window?.topController?.view
                #expect((controller.popoverPresentationController) == (popover))
                expect.fulfill()
            }),
            completion: { controller, isSuccess in
                responder = controller
                result = isSuccess
                expect1.fulfill()
            }
        )

        await fulfillment(of: [expect, expect1], timeout: 10)

        #expect((true) == (result))
        #expect(MockRootControllerNavigationIdentity().isEqual(to: window?.rootViewController?.navigationIdentity))
        #expect(identity.isEqual(to: window?.topController?.navigationIdentity))
        #expect((responder) == (window?.topController))
        let popover = try #require(responder?.popoverPresentationController)
        let delegate = try #require(popover.delegate)
        #expect(
            delegate.adaptivePresentationStyle?(for: popover)
                == UIModalPresentationStyle.none
        )
    }

    @Test
    func `Popover preserves a custom presentation delegate`() async throws {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigation(navigator: navigator)
        let customDelegate = CustomPopoverDelegate()
        let expect = expectation(description: "custom popover delegate")
        var configuredPopover: UIPopoverPresentationController?
        var result: Bool?

        navigator.navigate(
            destination: .identity(MockPushControllerNavigationIdentity()),
            strategy: .popover(configure: { popover, _ in
                configuredPopover = popover
                popover.sourceView = self.window?.topController?.view
                popover.delegate = customDelegate
            }),
            animated: false,
            completion: { _, isSuccess in
                result = isSuccess
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        let popover = try #require(configuredPopover)
        #expect((true) == result)
        #expect(popover.delegate === customDelegate)
    }

    @Test
    func `Default popover delegate survives navigator deallocation`() async throws {
        let rootController = UIViewController()
        window?.rootViewController = rootController
        window?.makeKeyAndVisible()
        let presentedController = UIViewController()
        var navigator: Navigator? = Navigator(window: window, screenFactory: MockScreenFactory())
        weak let weakNavigator = navigator
        let expect = expectation(description: "popover presentation")
        var result: Bool?

        navigator?.navigate(
            destination: .controller(presentedController),
            strategy: .popover(configure: { [weak rootController] popover, _ in
                popover.sourceView = rootController?.view
            }),
            animated: false,
            completion: { _, isSuccess in
                result = isSuccess
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        let popover = try #require(presentedController.popoverPresentationController)
        #expect((true) == result)
        navigator = nil
        #expect(weakNavigator == nil)
        let delegate = try #require(popover.delegate)
        #expect(
            delegate.adaptivePresentationStyle?(for: popover)
                == UIModalPresentationStyle.none
        )
    }

    @Test
    func `Popover rejects presenting the source controller`() async {
        let rootController = UIViewController()
        window?.rootViewController = rootController
        window?.makeKeyAndVisible()
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let expect = expectation(description: "rejected popover")
        var configureWasCalled = false
        var responder: UIViewController?
        var result: Bool?

        navigator.navigate(
            destination: .controller(rootController),
            strategy: .popover(configure: { _, _ in configureWasCalled = true }),
            animated: false,
            completion: { controller, isSuccess in
                responder = controller
                result = isSuccess
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((false) == result)
        #expect(responder == nil)
        #expect(!configureWasCalled)
        #expect(rootController.presentedViewController == nil)
    }

    @Test
    func `Popover navigation reports failure`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())

        #expect((window?.rootViewController) == nil)

        let identity = MockPushControllerNavigationIdentity()
        let expect = expectation(description: "presentation")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .popover(configure: { _, _ in
                Issue.record("Should not be called")
            }),
            completion: { controller, isSuccess in
                responder = controller
                result = isSuccess
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((false) == (result))
        #expect((responder) == nil)
    }

    @Test
    func `Popover failure uses fallback`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let fallbackIdentity = MockRootControllerNavigationIdentity()
        let expect = expectation(description: "fallback")
        var responder: UIViewController?
        var result: Bool?

        navigator.navigate(
            destination: .identity(MockPushControllerNavigationIdentity()),
            strategy: .popover(configure: { _, _ in
                Issue.record("Should not be called")
            }),
            fallback: NavigationChainLink(
                destination: .identity(fallbackIdentity),
                strategy: .replaceWindowRoot(),
                animated: false
            ),
            completion: { controller, isSuccess in
                responder = controller
                result = isSuccess
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((true) == (result))
        #expect(fallbackIdentity.isEqual(to: responder?.navigationIdentity))
        #expect(fallbackIdentity.isEqual(to: window?.rootViewController?.navigationIdentity))
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
}

private final class CustomPopoverDelegate: NSObject, UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        .none
    }
}
