//
//  PresentOrCloseToExistingControllerTests.swift
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
final class PresentOrCloseToExistingControllerTests {
    let window: UIWindow? = UIWindow()

    @Test
    func `Closes to existing controller`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigation(navigator: navigator)
        let identity = MockRootControllerNavigationIdentity()

        #expect(!(identity.isEqual(to: window?.topController?.navigationIdentity)))
        #expect((window?.findController(destination: .identity(identity))) != nil)

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

        await fulfillment(of: [expect], timeout: 10)

        #expect((true) == (result))
        #expect(identity.isEqual(to: window?.topController?.navigationIdentity))
        #expect((true) == ((window?.topController as? MockViewController)?.isMockEventHandled))
        #expect((true) == ((responder as? MockViewController)?.isMockEventHandled))
    }

    @Test
    func `Presents fallback when existing controller is absent`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigation(navigator: navigator)
        let identity = MockPopControllerNavigationIdentity()

        #expect(!(identity.isEqual(to: window?.topController?.navigationIdentity)))
        #expect((window?.findController(destination: .identity(identity))) == nil)

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

        await fulfillment(of: [expect], timeout: 10)

        #expect((true) == (result))
        #expect(identity.isEqual(to: window?.topController?.navigationIdentity))
        #expect((true) == ((responder as? MockViewController)?.isMockEventHandled))
    }

    @Test
    func `Close to existing reports failure without fallback`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigation(navigator: navigator)
        let identity = MockPopControllerNavigationIdentity()

        #expect(!(identity.isEqual(to: window?.topController?.navigationIdentity)))
        #expect((window?.findController(destination: .identity(identity))) == nil)

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

        await fulfillment(of: [expect], timeout: 10)

        #expect((false) == (result))
        #expect(!(identity.isEqual(to: window?.topController?.navigationIdentity)))
        #expect((window?.findController(destination: .identity(identity))) == nil)
    }

    @Test
    func `Presents controller`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigation(navigator: navigator)
        let identity = MockPopControllerNavigationIdentity()

        #expect(!(identity.isEqual(to: window?.topController?.navigationIdentity)))
        #expect((window?.findController(destination: .identity(identity))) == nil)

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

        await fulfillment(of: [expect], timeout: 10)

        #expect((true) == (result))
        #expect(identity.isEqual(to: window?.topController?.navigationIdentity))
        #expect((true) == ((responder as? MockViewController)?.isMockEventHandled))
    }

    @Test
    func `Presentation waits for custom transition completion`() async {
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

        await fulfillment(of: [expect], timeout: 10)

        #expect((true) == (result))
        #expect((elapsed ?? 0) >= (0.7))
        #expect((controller) == (window?.topController))
    }

    @Test
    func `Presents from navigation controller`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationControllerNavigation(navigator: navigator)
        let identity = MockPopControllerNavigationIdentity()

        #expect(window?.rootViewController is UINavigationController)
        #expect(!(identity.isEqual(to: window?.topController?.navigationIdentity)))
        #expect((window?.findController(destination: .identity(identity))) == nil)

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

        await fulfillment(of: [expect], timeout: 10)

        #expect((true) == (result))
        #expect(identity.isEqual(to: window?.topController?.navigationIdentity))
        #expect((true) == ((responder as? MockViewController)?.isMockEventHandled))
    }

    @Test
    func `Presents from tab bar controller`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareTabBar(navigator: navigator)
        let identity = MockPopControllerNavigationIdentity()

        #expect(window?.rootViewController is UITabBarController)
        #expect(!(identity.isEqual(to: window?.topController?.navigationIdentity)))
        #expect((window?.findController(destination: .identity(identity))) == nil)

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

        await fulfillment(of: [expect], timeout: 10)

        #expect((true) == (result))
        #expect(identity.isEqual(to: window?.topController?.navigationIdentity))
        #expect((true) == ((responder as? MockViewController)?.isMockEventHandled))
    }

    @Test
    func `Presentation from tab bar navigation controller reports failure`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigation(navigator: navigator)
        let identity = MockPopControllerNavigationIdentity()

        #expect(!(identity.isEqual(to: window?.topController?.navigationIdentity)))
        #expect((window?.findController(destination: .identity(identity))) == nil)

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

        await fulfillment(of: [expect], timeout: 10)

        #expect((false) == (result))
        #expect((responder) == nil)
        #expect(!(identity.isEqual(to: window?.topController?.navigationIdentity)))
        #expect((window?.findController(destination: .identity(identity))) == nil)
    }

    @Test
    func `Presentation uses fallback when requested source is unavailable`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationControllerNavigation(navigator: navigator)
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

        await fulfillment(of: [expect], timeout: 10)

        #expect((true) == (result))
        #expect(identity.isEqual(to: window?.topController?.navigationIdentity))
        #expect((true) == ((responder as? MockViewController)?.isMockEventHandled))
    }

    @Test
    func `Presentation without window reports failure`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let identity = MockPopControllerNavigationIdentity()

        #expect(!(identity.isEqual(to: window?.topController?.navigationIdentity)))
        #expect((window?.findController(destination: .identity(identity))) == nil)

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

        await fulfillment(of: [expect], timeout: 10)

        #expect((false) == (result))
        #expect((responder) == nil)
        #expect(!(identity.isEqual(to: window?.topController?.navigationIdentity)))
        #expect((window?.findController(destination: .identity(identity))) == nil)
    }

    func prepareTabBar(navigator: Navigator) async {
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

        await fulfillment(of: [expect], timeout: 10)
    }

    func prepareNavigationControllerNavigation(navigator: Navigator) async {
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

        await fulfillment(of: [expect], timeout: 10)
    }

    func prepareNavigation(navigator: Navigator) async {
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

        await fulfillment(of: [expect], timeout: 10)
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
