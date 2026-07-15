//
//  SetRootControllerTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 06.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit
import VANavigator
import XCTest

// TODO: - Messages
class SetRootControllerTests: XCTestCase {
    var window: UIWindow?

    override func setUp() async throws {
        window = UIWindow()
    }

    override func tearDown() async throws {
        window = nil
    }

    func test_setRootController() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())

        XCTAssertNil(window?.rootViewController)

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

        XCTAssertEqual(true, result)
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.rootViewController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: responder?.navigationIdentity))
        XCTAssertEqual(true, (responder as? MockViewController)?.isMockEventHandled)
        XCTAssertEqual(false, (responder as? MockRootViewController)?.isReplacedEventHandled)
    }

    func test_setRootController_embeddingInNavigation() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())

        XCTAssertNil(window?.rootViewController)

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

        XCTAssertNotNil(rootNavigationController)
        XCTAssertTrue(rootNavigationController?.viewControllers.count == 1)
        XCTAssertTrue(expectedIdentity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertEqual(true, (window?.topController as? MockViewController)?.isMockEventHandled)
        XCTAssertEqual(false, (window?.topController as? MockRootViewController)?.isReplacedEventHandled)
    }

    func test_replaceExistingRootController() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        window?.rootViewController = UIViewController()
        window?.makeKeyAndVisible()

        XCTAssertNotNil(window?.rootViewController)

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

        XCTAssertTrue(expectedIdentity.isEqual(to: window?.rootViewController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(expectedIdentity.isEqual(to: responder?.navigationIdentity))
        XCTAssertEqual(true, (responder as? MockViewController)?.isMockEventHandled)
        XCTAssertEqual(true, (responder as? MockRootViewController)?.isReplacedEventHandled)
    }

    func test_replaceExistingRootController_waitsForResponderEventsBeforeCompletion() async {
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

        XCTAssertEqual(["navigator", "user"], handledEventsAtCompletion)
        XCTAssertEqual(["navigator", "user"], responder.handledEvents)
    }

    func test_replaceWindowRoot_withoutWindowReportsFailure() async {
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

        XCTAssertNil(responder)
        XCTAssertEqual(false, result)
    }

    func test_setRootController_transitionCompletionWaitsForAnimation() async {
        guard
            let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first
        else {
            XCTFail("Missing window scene")

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
        let start = ProcessInfo.processInfo.systemUptime
        var elapsed: TimeInterval?

        window?.set(rootViewController: newController, transition: transition) {
            elapsed = ProcessInfo.processInfo.systemUptime - start
            expect.fulfill()
        }

        XCTAssertIdentical(newController, window?.rootViewController)
        XCTAssertNil(elapsed)
        await fulfillment(of: [expect], timeout: 10)

        XCTAssertGreaterThanOrEqual(elapsed ?? 0, 0.15)
    }

    func test_setRootController_transitionRetainsAndForwardsDelegate() async {
        guard
            let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first
        else {
            XCTFail("Missing window scene")

            return
        }

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = UIViewController()
        window?.makeKeyAndVisible()
        let forwarded = expectation(description: "forwarded animation delegate")
        let completed = expectation(description: "root transition")
        weak var retainedDelegate: RootTransitionDelegate?

        func startTransition() {
            let transition = CATransition()
            transition.duration = 0.1
            let delegate = RootTransitionDelegate {
                forwarded.fulfill()
            }
            retainedDelegate = delegate
            transition.delegate = delegate
            window?.set(
                rootViewController: UIViewController(),
                transition: transition,
                completion: { completed.fulfill() }
            )
        }

        startTransition()

        XCTAssertNotNil(retainedDelegate)
        await fulfillment(of: [forwarded, completed], timeout: 10)
    }

    func test_setWithoutAnimation() async {
        XCTAssertNil(window?.rootViewController)
        let animationsWereEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(animationsWereEnabled) }

        window?.set(rootViewController: UIViewController())

        XCTAssertNotNil(window?.rootViewController)
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
                taskDetachedMain { expect.fulfill() }
            }
        )
        await fulfillment(of: [expect], timeout: 10)
        completion?(responder, result)
    }
}

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
