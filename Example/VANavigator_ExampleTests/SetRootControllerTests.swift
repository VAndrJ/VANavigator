//
//  SetRootControllerTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 06.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Testing
import UIKit
@testable import VANavigator

// TODO: - Messages
@Suite(.serialized)
final class SetRootControllerTests {
    var window: UIWindow? = UIWindow()

    @Test
    func `Sets window root controller`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())

        #expect((window?.rootViewController) == nil)

        let identity = MockRootControllerNavigationIdentity()
        var responder: UIViewController?
        let expect = expectation(description: "replace")
        var result: Bool?
        await replaceWindowRoot(
            navigator: navigator,
            identity: identity,
            alwaysEmbedded: false,
            completion: { controller, isSuccess in
                result = isSuccess
                responder = controller
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        // Сhecking that the `UIWindow`'s root view controller identity is equal to given
        // and it is the top view controller.
        let expectedIdentity = identity

        #expect((true) == (result))
        #expect(expectedIdentity.isEqual(to: window?.rootViewController?.navigationIdentity))
        #expect(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        #expect(expectedIdentity.isEqual(to: responder?.navigationIdentity))
        #expect((true) == ((responder as? MockViewController)?.isMockEventHandled))
        #expect((false) == ((responder as? MockRootViewController)?.isReplacedEventHandled))
    }

    @Test
    func `Sets root controller embedded in navigation`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())

        #expect((window?.rootViewController) == nil)

        let identity = MockRootControllerNavigationIdentity()
        await replaceWindowRoot(
            navigator: navigator,
            identity: identity,
            alwaysEmbedded: true,
            completion: nil
        )

        // Сhecking that the `UIWindow`'s root view controller is `UINavigationController`
        // and it's root controller's identity is equal to given and it is the top view controller.
        let rootNavigationController = window?.rootViewController as? UINavigationController
        let expectedIdentity = identity

        #expect((rootNavigationController) != nil)
        #expect(rootNavigationController?.viewControllers.count == 1)
        #expect(expectedIdentity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity))
        #expect(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        #expect((true) == ((window?.topController as? MockViewController)?.isMockEventHandled))
        #expect((false) == ((window?.topController as? MockRootViewController)?.isReplacedEventHandled))
    }

    @Test
    func `Replaces existing root controller`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        window?.rootViewController = UIViewController()
        window?.makeKeyAndVisible()

        #expect((window?.rootViewController) != nil)

        let identity = MockRootControllerNavigationIdentity()
        var responder: UIViewController?
        let expect = expectation(description: "replace")
        await replaceWindowRoot(
            navigator: navigator,
            identity: identity,
            alwaysEmbedded: false,
            completion: { controller, _ in
                responder = controller
                expect.fulfill()
            }
        )
        await fulfillment(of: [expect], timeout: 10)

        // Сhecking that the `UIWindow`'s root view controller identity is equal to given
        // and it is the top view controller.
        let expectedIdentity = identity

        #expect(expectedIdentity.isEqual(to: window?.rootViewController?.navigationIdentity))
        #expect(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        #expect(expectedIdentity.isEqual(to: responder?.navigationIdentity))
        #expect((true) == ((responder as? MockViewController)?.isMockEventHandled))
        #expect((true) == ((responder as? MockRootViewController)?.isReplacedEventHandled))
    }

    @Test
    func `Replacement waits for responder events before completion`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        window?.rootViewController = UIViewController()
        window?.makeKeyAndVisible()
        let responder = DelayedResponderViewController()

        let expect = expectation(description: "replace")
        var handledEventsAtCompletion: [String] = []
        navigator.navigate(
            destination: .controller(responder),
            strategy: .replaceWindowRoot(),
            animated: false,
            event: DelayedResponderEvent(),
            completion: { _, _ in
                handledEventsAtCompletion = responder.handledEvents
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((["navigator", "user"]) == (handledEventsAtCompletion))
        #expect((["navigator", "user"]) == (responder.handledEvents))
    }

    @Test
    func `Replacement without window reports failure`() async {
        let navigator = Navigator(window: nil, screenFactory: MockScreenFactory())
        let controller = UIViewController()
        let expect = expectation(description: "replace without window")
        var responder: UIViewController?
        var result: Bool?

        navigator.navigate(
            destination: .controller(controller),
            strategy: .replaceWindowRoot(),
            animated: false,
            completion: { completedController, isSuccess in
                responder = completedController
                result = isSuccess
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((responder) == nil)
        #expect((false) == (result))
    }

    @Test
    func `Replacement without animation ignores configured transition`() async {
        guard let window else {
            Issue.record("Missing window")

            return
        }

        window.rootViewController = UIViewController()
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let controller = UIViewController()
        let transition = CATransition()
        transition.duration = 0.1
        let expect = expectation(description: "replace without animation")
        var completionWasSynchronous = false
        var result: Bool?

        navigator.navigate(
            destination: .controller(controller),
            strategy: .replaceWindowRoot(transition: transition),
            animated: false,
            completion: { completedController, isSuccess in
                completionWasSynchronous = true
                result = isSuccess
                #expect((controller) === (completedController))
                expect.fulfill()
            }
        )

        #expect(completionWasSynchronous)
        #expect((window.layer.animation(forKey: kCATransition)) == nil)
        await fulfillment(of: [expect], timeout: 10)

        #expect((true) == (result))
        #expect((controller) === (window.rootViewController))
    }

    @Test
    func `Window rejects a repeating root transition without mutating its root`() {
        guard let window else {
            Issue.record("Missing window")

            return
        }

        let initialController = UIViewController()
        let rejectedController = UIViewController()
        window.rootViewController = initialController
        let transition = CATransition()
        transition.duration = 0.1
        transition.repeatCount = .greatestFiniteMagnitude
        var completionCount = 0

        window.set(rootViewController: rejectedController, transition: transition) {
            completionCount += 1
        }

        #expect(completionCount == 1)
        #expect(window.rootViewController === initialController)
        #expect(window.layer.animation(forKey: kCATransition) == nil)
    }

    @Test
    func `Invalid root transition reports failure and releases navigation state`() async {
        guard let window else {
            Issue.record("Missing window")

            return
        }

        let initialController = UIViewController()
        let rejectedController = UIViewController()
        let acceptedController = UIViewController()
        window.rootViewController = initialController
        let transition = CATransition()
        transition.duration = 0.1
        transition.repeatCount = .greatestFiniteMagnitude
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        var failures: [NavigationFailure.Reason] = []
        navigator.navigationFailureHandler = { failures.append($0.reason) }
        let rejected = expectation(description: "invalid root transition")
        let accepted = expectation(description: "navigation after invalid root transition")
        var completionOrder: [String] = []

        navigator.navigate(
            destination: .controller(rejectedController),
            strategy: .replaceWindowRoot(transition: transition),
            animated: true,
            completion: { controller, isSuccess in
                #expect(controller == nil)
                #expect(!isSuccess)
                completionOrder.append("rejected")
                rejected.fulfill()
            }
        )
        navigator.navigate(
            destination: .controller(acceptedController),
            strategy: .replaceWindowRoot(),
            animated: false,
            completion: { controller, isSuccess in
                #expect(controller === acceptedController)
                #expect(isSuccess)
                completionOrder.append("accepted")
                accepted.fulfill()
            }
        )

        await fulfillment(of: [rejected, accepted], timeout: 10)

        #expect(failures == [.invalidTransitionConfiguration])
        #expect(completionOrder == ["rejected", "accepted"])
        #expect(window.rootViewController === acceptedController)
        #expect(window.layer.animation(forKey: kCATransition) == nil)
    }

    @Test
    func `Root transition timing validation rejects configurations that may not finish`() {
        let validTransition = CATransition()
        validTransition.duration = 0.25
        #expect(validTransition.isSupportedNavigatorRootTransition)

        let pausedTransition = CATransition()
        pausedTransition.duration = 0.25
        pausedTransition.speed = 0
        #expect(!pausedTransition.isSupportedNavigatorRootTransition)

        let delayedTransition = CATransition()
        delayedTransition.duration = 0.25
        delayedTransition.beginTime = CACurrentMediaTime() + 1
        #expect(!delayedTransition.isSupportedNavigatorRootTransition)

        let offsetTransition = CATransition()
        offsetTransition.duration = 0.25
        offsetTransition.timeOffset = 0.1
        #expect(!offsetTransition.isSupportedNavigatorRootTransition)

        let repeatingTransition = CATransition()
        repeatingTransition.duration = 0.25
        repeatingTransition.repeatCount = 2
        #expect(!repeatingTransition.isSupportedNavigatorRootTransition)
    }

    @Test
    func `Transition completion waits for animation`() async {
        guard
            let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first
        else {
            Issue.record("Missing window scene")

            return
        }

        window = UIWindow(windowScene: windowScene)
        let previousController = UIViewController()
        let newController = UIViewController()
        window?.rootViewController = previousController
        window?.makeKeyAndVisible()
        let transition = CATransition()
        transition.duration = 0.25
        let expect = expectation(description: "root transition")
        var delegateDidStop = false
        let delegate = RootTransitionDelegate {
            delegateDidStop = true
        }
        transition.delegate = delegate
        var delegateHadStoppedAtCompletion: Bool?

        window?.set(rootViewController: newController, transition: transition) {
            delegateHadStoppedAtCompletion = delegateDidStop
            expect.fulfill()
        }

        #expect((newController) === (window?.rootViewController))
        #expect(!delegateDidStop)
        #expect(delegateHadStoppedAtCompletion == nil)
        await fulfillment(of: [expect], timeout: 10)

        #expect(delegateDidStop)
        #expect((true) == delegateHadStoppedAtCompletion)
    }

    @Test
    func `Transition retains and forwards delegate`() async {
        guard
            let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first
        else {
            Issue.record("Missing window scene")

            return
        }

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = UIViewController()
        window?.makeKeyAndVisible()
        let forwarded = expectation(description: "forwarded animation delegate")
        let completed = expectation(description: "root transition")
        weak var retainedDelegate: RootTransitionDelegate?
        var callbackOrder: [String] = []

        func startTransition() {
            let transition = CATransition()
            transition.duration = 0.1
            let delegate = RootTransitionDelegate {
                callbackOrder.append("forwarded")
                forwarded.fulfill()
            }
            retainedDelegate = delegate
            transition.delegate = delegate
            window?.set(
                rootViewController: UIViewController(),
                transition: transition,
                completion: {
                    callbackOrder.append("completed")
                    completed.fulfill()
                }
            )
        }

        startTransition()

        #expect((retainedDelegate) != nil)
        await fulfillment(of: [forwarded, completed], timeout: 10)
        #expect(callbackOrder == ["forwarded", "completed"])
    }

    @Test
    func `Sets root controller while animations are disabled`() async {
        #expect((window?.rootViewController) == nil)
        let animationsWereEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(animationsWereEnabled) }

        window?.set(rootViewController: UIViewController())

        #expect((window?.rootViewController) != nil)
    }

    func replaceWindowRoot(
        navigator: Navigator,
        identity: any NavigationIdentity,
        alwaysEmbedded: Bool,
        completion: ((UIViewController?, Bool) -> Void)?
    ) async {
        let expect = expectation(description: "navigation")
        var responder: UIViewController?
        var result = false
        navigator.navigate(
            destination: .identity(alwaysEmbedded ? MockNavControllerNavigationIdentity(children: [identity]) : identity),
            strategy: .replaceWindowRoot(),
            event: ResponderMockEvent(),
            completion: {
                responder = $0
                result = $1
                expect.fulfill()
            }
        )
        await fulfillment(of: [expect], timeout: 10)
        completion?(responder, result)
    }
}

@MainActor
private struct DelayedResponderEvent: ResponderEvent {}

private final class DelayedResponderViewController: UIViewController, Responder {
    var nextEventResponder: (any Responder)?
    private(set) var handledEvents: [String] = []

    func handle(event: any ResponderEvent) async -> Bool {
        switch event {
        case _ as ResponderReplacedWindowRootControllerEvent:
            handledEvents.append("navigator")

            return true
        case _ as DelayedResponderEvent:
            try? await Task.sleep(nanoseconds: 50_000_000)
            handledEvents.append("user")

            return true
        default:
            return false
        }
    }
}

private final class RootTransitionDelegate: NSObject, CAAnimationDelegate {
    private let onStop: () -> Void

    init(onStop: @escaping () -> Void) {
        self.onStop = onStop
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        onStop()
    }
}
