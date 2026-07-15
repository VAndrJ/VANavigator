//
//  PresentOrCloseToExistingControllerTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 15.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit
import VANavigator
import XCTest

// TODO: - Messages
@MainActor
class PresentOrCloseToExistingControllerTests: XCTestCase {
    var window: UIWindow?

    override func setUp() async throws {
        window = UIWindow()
    }

    override func tearDown() async throws {
        window = nil
    }

    func test_controllerCloseToExisting() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigation(navigator: navigator)
        let identity = MockRootControllerNavigationIdentity()

        XCTAssertFalse(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertNotNil(window?.findController(destination: .identity(identity)))

        let expect = expectation(description: "replace")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .closeToExisting,
            fallback: NavigationChainLink(
                destination: .identity(identity),
                strategy: .present(),
                animated: true
            ),
            event: ResponderMockEvent(),
            completion: { controller, isSuccess in
                responder = controller
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertTrue(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertEqual(true, (window?.topController as? MockViewController)?.isMockEventHandled)
        XCTAssertEqual(true, (responder as? MockViewController)?.isMockEventHandled)
    }

    func test_controllerCloseToExisting_presented() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigation(navigator: navigator)
        let identity = MockPopControllerNavigationIdentity()

        XCTAssertFalse(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertNil(window?.findController(destination: .identity(identity)))

        let expect = expectation(description: "replace")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .closeToExisting,
            fallback: NavigationChainLink(
                destination: .identity(identity),
                strategy: .present(),
                animated: true
            ),
            event: ResponderMockEvent(),
            completion: { controller, isSuccess in
                responder = controller
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertTrue(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertEqual(true, (responder as? MockViewController)?.isMockEventHandled)
    }

    func test_controllerCloseToExisting_failure() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigation(navigator: navigator)
        let identity = MockPopControllerNavigationIdentity()

        XCTAssertFalse(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertNil(window?.findController(destination: .identity(identity)))

        let expect = expectation(description: "replace")
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .closeToExisting,
            event: ResponderMockEvent(),
            completion: { _, isSuccess in
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(false, result)
        XCTAssertFalse(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertNil(window?.findController(destination: .identity(identity)))
    }

    func test_controller_presented() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigation(navigator: navigator)
        let identity = MockPopControllerNavigationIdentity()

        XCTAssertFalse(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertNil(window?.findController(destination: .identity(identity)))

        let expect = expectation(description: "replace")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .present(),
            event: ResponderMockEvent(),
            completion: { controller, isSuccess in
                responder = controller
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertTrue(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertEqual(true, (responder as? MockViewController)?.isMockEventHandled)
    }

    func test_controller_presented_waitsForCustomTransitionCompletion() {
        let rootController = UIViewController()
        window?.rootViewController = rootController
        window?.makeKeyAndVisible()

        let transitionDuration: TimeInterval = 0.8
        let transitionDelegate = DelayedPresentationTransitioningDelegate(duration: transitionDuration)
        let controller = UIViewController()
        controller.modalPresentationStyle = .custom
        controller.transitioningDelegate = transitionDelegate
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let start = ProcessInfo.processInfo.systemUptime
        let expect = expectation(description: "custom presentation")
        var elapsed: TimeInterval?
        var result: Bool?

        navigator.navigate(
            destination: .controller(controller),
            strategy: .present(),
            animated: true,
            completion: { _, isSuccess in
                elapsed = ProcessInfo.processInfo.systemUptime - start
                result = isSuccess
                expect.fulfill()
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertGreaterThanOrEqual(elapsed ?? 0, 0.7)
        XCTAssertEqual(controller, window?.topController)
    }

    func test_controller_presented_fromNavigationController() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationControllerNavigation(navigator: navigator)
        let identity = MockPopControllerNavigationIdentity()

        XCTAssertTrue(window?.rootViewController is UINavigationController)
        XCTAssertFalse(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertNil(window?.findController(destination: .identity(identity)))

        let expect = expectation(description: "replace")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .present(source: .navigationController),
            event: ResponderMockEvent(),
            completion: { controller, isSuccess in
                responder = controller
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertTrue(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertEqual(true, (responder as? MockViewController)?.isMockEventHandled)
    }

    func test_controller_presented_fromTabBarController() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareTabBar(navigator: navigator)
        let identity = MockPopControllerNavigationIdentity()

        XCTAssertTrue(window?.rootViewController is UITabBarController)
        XCTAssertFalse(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertNil(window?.findController(destination: .identity(identity)))

        let expect = expectation(description: "replace")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .present(source: .tabBarController),
            event: ResponderMockEvent(),
            completion: { controller, isSuccess in
                responder = controller
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertTrue(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertEqual(true, (responder as? MockViewController)?.isMockEventHandled)
    }

    func test_controller_presenting_fromTabBarNavControllerFailure() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigation(navigator: navigator)
        let identity = MockPopControllerNavigationIdentity()

        XCTAssertFalse(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertNil(window?.findController(destination: .identity(identity)))

        let expect = expectation(description: "replace")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .present(source: .tabBarController),
            fallbackStrategies: [.present(source: .navigationController)],
            event: ResponderMockEvent(),
            completion: { controller, isSuccess in
                responder = controller
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(false, result)
        XCTAssertNil(responder)
        XCTAssertFalse(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertNil(window?.findController(destination: .identity(identity)))
    }

    func test_controller_presenting_usesFallbackWhenRequestedSourceIsUnavailable() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationControllerNavigation(navigator: navigator)
        let identity = MockPopControllerNavigationIdentity()
        let expect = expectation(description: "present fallback")
        var responder: UIViewController?
        var result: Bool?

        navigator.navigate(
            destination: .identity(identity),
            strategy: .present(source: .tabBarController),
            fallbackStrategies: [.present(source: .navigationController)],
            event: ResponderMockEvent(),
            completion: { controller, isSuccess in
                responder = controller
                result = isSuccess
                expect.fulfill()
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertTrue(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertEqual(true, (responder as? MockViewController)?.isMockEventHandled)
    }

    func test_controller_presenting_withoutWindowFailure() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let identity = MockPopControllerNavigationIdentity()

        XCTAssertFalse(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertNil(window?.findController(destination: .identity(identity)))

        let expect = expectation(description: "replace")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .present(source: .tabBarController),
            fallbackStrategies: [
                .present(source: .navigationController),
                .present(source: .topController),
            ],
            event: ResponderMockEvent(),
            completion: { controller, isSuccess in
                responder = controller
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(false, result)
        XCTAssertNil(responder)
        XCTAssertFalse(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertNil(window?.findController(destination: .identity(identity)))
    }

    func prepareTabBar(navigator: Navigator) {
        let expect = expectation(description: "navigation.replaceWindowRoot")
        navigator.navigate(
            chain: [
                NavigationChainLink(
                    destination: .controller(UITabBarController()),
                    strategy: .replaceWindowRoot(),
                    animated: true
                )
            ],
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)
    }

    func prepareNavigationControllerNavigation(navigator: Navigator) {
        let expect = expectation(description: "navigation.replaceWindowRoot")
        navigator.navigate(
            chain: [
                NavigationChainLink(
                    destination: .identity(MockNavControllerNavigationIdentity(children: [MockRootControllerNavigationIdentity()])),
                    strategy: .replaceWindowRoot(),
                    animated: true
                )
            ],
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)
    }

    func prepareNavigation(navigator: Navigator) {
        let expect = expectation(description: "navigation.replaceWindowRoot")
        navigator.navigate(
            chain: [
                NavigationChainLink(
                    destination: .identity(MockRootControllerNavigationIdentity()),
                    strategy: .replaceWindowRoot(),
                    animated: true
                ),
                NavigationChainLink(
                    destination: .identity(MockPushControllerNavigationIdentity()),
                    strategy: .present(),
                    animated: false
                ),
                NavigationChainLink(
                    destination: .controller(UIViewController()),
                    strategy: .present(),
                    animated: false
                ),
            ],
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)
    }
}

private final class DelayedPresentationTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    private let animator: DelayedPresentationAnimator

    init(duration: TimeInterval) {
        animator = DelayedPresentationAnimator(duration: duration)
    }

    func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController
    ) -> (any UIViewControllerAnimatedTransitioning)? {
        animator
    }
}

private final class DelayedPresentationAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private let duration: TimeInterval

    init(duration: TimeInterval) {
        self.duration = duration
    }

    func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
        duration
    }

    func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
        guard let presentedView = transitionContext.view(forKey: .to) else {
            transitionContext.completeTransition(false)

            return
        }

        transitionContext.containerView.addSubview(presentedView)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}
