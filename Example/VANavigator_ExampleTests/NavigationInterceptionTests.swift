//
//  NavigationInterceptionTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 16.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Testing
import UIKit
import VANavigator

private struct LoginRequiredNavigationInterceptionReason: Hashable {}

private final class TestAuthorizationService {
    private(set) var isAuthorized = false
    var onAuthorization: (() -> Void)?

    func authorize() {
        isAuthorized = true
        onAuthorization?()
    }
}

@Suite(.serialized)
final class NavigationInterceptionTests {
    let window: UIWindow? = UIWindow()

    @Test
    func `Default interceptor does not intercept`() async {
        let sut = MockEmptyInterceptor()

        #expect((sut.intercept(destination: .identity(MockControllerNavigationIdentity()))) == nil)
    }

    @Test
    func `Intercepted navigation resumes after resolution`() async {
        let authorizationService = TestAuthorizationService()
        let navigationInterceptor = MockNavigationInterceptor(authorizationService: authorizationService)
        let navigator = Navigator(
            window: window,
            screenFactory: MockScreenFactory(),
            navigationInterceptor: navigationInterceptor
        )
        await preparePresented(navigator: navigator)
        let identity = SecretInformationIdentity()
        let requestedNavigation = expectation(description: "requested navigation")
        var requestedController: UIViewController?
        var requestedResult: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .present(),
            animated: false,
            completion: { controller, isSuccess in
                requestedController = controller
                requestedResult = isSuccess
                requestedNavigation.fulfill()
            }
        )

        await waitUntil("interception navigation", timeout: 10) {
            navigationInterceptor.interceptionIdentity.isEqual(to: window?.topController?.navigationIdentity)
                && navigationInterceptor.checkIsExists(reason: navigationInterceptor.interceptionReason)
        }

        #expect(!requestedNavigation.isFulfilled)
        #expect(!(identity.isEqual(to: window?.topController?.navigationIdentity)))
        #expect(navigationInterceptor.interceptionIdentity.isEqual(to: window?.topController?.navigationIdentity))
        #expect(navigationInterceptor.checkIsExists(reason: navigationInterceptor.interceptionReason))
        #expect(([navigationInterceptor.interceptionReason]) == (navigationInterceptor.getInterceptionReasons()))

        let expect1 = expectation(description: "navigation.resolved")
        navigationInterceptor.completion = { _, _ in taskDetachedMain { expect1.fulfill() } }
        authorizationService.authorize()

        await fulfillment(of: [requestedNavigation, expect1], timeout: 10)

        #expect((true) == requestedResult)
        #expect(identity.isEqual(to: requestedController?.navigationIdentity))
        #expect(identity.isEqual(to: window?.topController?.navigationIdentity))
        #expect(identity.isEqual(to: window?.rootViewController?.navigationIdentity))
    }

    @Test
    func `Interceptor assigned after initialization intercepts navigation`() async {
        let authorizationService = TestAuthorizationService()
        let navigationInterceptor = MockNavigationInterceptor(authorizationService: authorizationService)
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        navigator.navigationInterceptor = navigationInterceptor
        await preparePresented(navigator: navigator)
        let identity = SecretInformationIdentity()
        let requestedNavigation = expectation(description: "requested navigation")
        navigator.navigate(
            destination: .identity(identity),
            strategy: .present(),
            animated: false,
            completion: { _, _ in requestedNavigation.fulfill() }
        )

        await waitUntil("interception navigation", timeout: 10) {
            navigationInterceptor.interceptionIdentity.isEqual(to: window?.topController?.navigationIdentity)
                && navigationInterceptor.checkIsExists(reason: navigationInterceptor.interceptionReason)
        }

        #expect(!requestedNavigation.isFulfilled)
        #expect(!(identity.isEqual(to: window?.topController?.navigationIdentity)))
        #expect(navigationInterceptor.interceptionIdentity.isEqual(to: window?.topController?.navigationIdentity))
        #expect(navigationInterceptor.checkIsExists(reason: navigationInterceptor.interceptionReason))

        let expect1 = expectation(description: "navigation.resolved")
        navigationInterceptor.completion = { _, _ in taskDetachedMain { expect1.fulfill() } }
        authorizationService.authorize()

        await fulfillment(of: [requestedNavigation, expect1], timeout: 10)

        #expect(identity.isEqual(to: window?.topController?.navigationIdentity))
        #expect(identity.isEqual(to: window?.rootViewController?.navigationIdentity))
    }

    @Test
    func `Interception chain starts before queued navigation`() async {
        let screenFactory = InterceptionOrderScreenFactory()
        let navigationInterceptor = QueuingNavigationInterceptor()
        let navigator = Navigator(
            window: window,
            screenFactory: screenFactory,
            navigationInterceptor: navigationInterceptor
        )
        navigationInterceptor.navigator = navigator
        await preparePresented(navigator: navigator)

        let requestedNavigation = expectation(description: "requested navigation")
        let queuedExpect = expectation(description: "navigation.queued")
        navigationInterceptor.onQueuedNavigationCompleted = {
            taskDetachedMain { queuedExpect.fulfill() }
        }
        navigator.navigate(
            destination: .identity(SecretInformationIdentity()),
            strategy: .present(),
            animated: false,
            completion: { _, _ in requestedNavigation.fulfill() }
        )

        await fulfillment(of: [queuedExpect], timeout: 10)

        #expect(!requestedNavigation.isFulfilled)
        #expect((["interception", "queued"]) == (screenFactory.trackedAssemblies))
    }

    @Test
    func `Navigations with the same reason resume in FIFO order`() async {
        let navigationInterceptor = RepeatedReasonNavigationInterceptor()
        let navigator = Navigator(
            window: window,
            screenFactory: MockScreenFactory(),
            navigationInterceptor: navigationInterceptor
        )
        let firstController = InterceptionTrackingViewController()
        let secondController = InterceptionTrackingViewController()
        let firstIntercepted = expectation(description: "first intercepted")
        let secondIntercepted = expectation(description: "second intercepted")

        navigator.navigate(
            destination: .controller(firstController),
            strategy: .replaceWindowRoot(),
            animated: false,
            event: RepeatedReasonNavigationEvent(),
            completion: { _, _ in firstIntercepted.fulfill() }
        )
        navigator.navigate(
            destination: .controller(secondController),
            strategy: .replaceWindowRoot(),
            animated: false,
            event: RepeatedReasonNavigationEvent(),
            completion: { _, _ in secondIntercepted.fulfill() }
        )

        #expect(!firstIntercepted.isFulfilled)
        #expect(!secondIntercepted.isFulfilled)
        #expect(([navigationInterceptor.reason]) == (navigationInterceptor.getInterceptionReasons()))

        let resolved = expectation(description: "interceptions resolved")
        var result: Bool?
        navigationInterceptor.resolve { _, isSuccess in
            result = isSuccess
            resolved.fulfill()
        }

        await fulfillment(of: [firstIntercepted, secondIntercepted, resolved], timeout: 10)

        #expect((true) == (result))
        #expect((1) == (firstController.handledEventCount))
        #expect((1) == (secondController.handledEventCount))
        #expect((secondController) === (window?.rootViewController))
    }

    @Test
    func `Shared interceptor resumes navigation in originating navigators`() async {
        let navigationInterceptor = RepeatedReasonNavigationInterceptor()
        let firstWindow = UIWindow()
        let secondWindow = UIWindow()
        let firstNavigator = Navigator(
            window: firstWindow,
            screenFactory: MockScreenFactory(),
            navigationInterceptor: navigationInterceptor
        )
        let secondNavigator = Navigator(
            window: secondWindow,
            screenFactory: MockScreenFactory(),
            navigationInterceptor: navigationInterceptor
        )
        let firstController = InterceptionTrackingViewController()
        let secondController = InterceptionTrackingViewController()
        let firstIntercepted = expectation(description: "first intercepted")
        let secondIntercepted = expectation(description: "second intercepted")

        firstNavigator.navigate(
            destination: .controller(firstController),
            strategy: .replaceWindowRoot(),
            animated: false,
            event: RepeatedReasonNavigationEvent(),
            completion: { _, _ in firstIntercepted.fulfill() }
        )
        secondNavigator.navigate(
            destination: .controller(secondController),
            strategy: .replaceWindowRoot(),
            animated: false,
            event: RepeatedReasonNavigationEvent(),
            completion: { _, _ in secondIntercepted.fulfill() }
        )

        #expect(!firstIntercepted.isFulfilled)
        #expect(!secondIntercepted.isFulfilled)
        #expect(([navigationInterceptor.reason]) == (navigationInterceptor.getInterceptionReasons()))

        let resolved = expectation(description: "interceptions resolved")
        var completedController: UIViewController?
        var result: Bool?
        navigationInterceptor.resolve { controller, isSuccess in
            completedController = controller
            result = isSuccess
            resolved.fulfill()
        }

        await fulfillment(of: [firstIntercepted, secondIntercepted, resolved], timeout: 10)

        #expect((true) == (result))
        #expect((secondController) === (completedController))
        #expect((firstController) === (firstWindow.rootViewController))
        #expect((secondController) === (secondWindow.rootViewController))
        #expect((1) == (firstController.handledEventCount))
        #expect((1) == (secondController.handledEventCount))
    }

    @Test
    func `Strategy override leaves original link unchanged`() async {
        let navigationInterceptor = RepeatedReasonNavigationInterceptor()
        let navigator = Navigator(
            window: window,
            screenFactory: MockScreenFactory(),
            navigationInterceptor: navigationInterceptor
        )
        let controller = UIViewController()
        let originalStrategy = NavigationStrategy.present()
        let link = NavigationChainLink(
            destination: .controller(controller),
            strategy: originalStrategy,
            animated: false
        )
        let intercepted = expectation(description: "navigation intercepted")
        navigator.navigate(chain: [link]) { _, _ in intercepted.fulfill() }

        #expect(!intercepted.isFulfilled)
        #expect(([navigationInterceptor.reason]) == (navigationInterceptor.getInterceptionReasons()))

        let resolved = expectation(description: "interception resolved")
        var result: Bool?
        navigationInterceptor.resolve(newStrategy: .replaceWindowRoot()) { _, isSuccess in
            result = isSuccess
            resolved.fulfill()
        }

        await fulfillment(of: [intercepted, resolved], timeout: 10)

        #expect((true) == (result))
        #expect((controller) === (window?.rootViewController))
        #expect((originalStrategy) === (link.strategy))
    }

    @Test
    func `Interception prefix is prepended to navigation chain`() async {
        let authorizationService = TestAuthorizationService()
        let navigationInterceptor = MockNavigationInterceptor(authorizationService: authorizationService, kind: .prefixed)
        let navigator = Navigator(
            window: window,
            screenFactory: MockScreenFactory(),
            navigationInterceptor: navigationInterceptor
        )
        await preparePresented(navigator: navigator)
        let identity = SecretInformationIdentity()
        let requestedNavigation = expectation(description: "requested navigation")
        navigator.navigate(
            chain: [
                NavigationChainLink(
                    destination: .identity(identity),
                    strategy: .present(),
                    animated: false
                )
            ],
            completion: { _, _ in requestedNavigation.fulfill() }
        )

        await waitUntil("interception navigation", timeout: 10) {
            navigationInterceptor.interceptionIdentity.isEqual(to: window?.topController?.navigationIdentity)
                && navigationInterceptor.checkIsExists(reason: navigationInterceptor.interceptionReason)
        }

        #expect(!requestedNavigation.isFulfilled)
        #expect((window?.findController(destination: .identity(navigationInterceptor.interceptionIdentity))) != nil)
        #expect(!(identity.isEqual(to: window?.topController?.navigationIdentity)))
        #expect(navigationInterceptor.interceptionIdentity.isEqual(to: window?.topController?.navigationIdentity))
        #expect(navigationInterceptor.checkIsExists(reason: navigationInterceptor.interceptionReason))
        #expect(([navigationInterceptor.interceptionReason]) == (navigationInterceptor.getInterceptionReasons()))

        let expect1 = expectation(description: "navigation.resolved")
        navigationInterceptor.completion = { _, _ in taskDetachedMain { expect1.fulfill() } }
        authorizationService.authorize()

        await fulfillment(of: [requestedNavigation, expect1], timeout: 10)

        #expect((window?.findController(destination: .identity(navigationInterceptor.interceptionIdentity))) == nil)
        #expect(identity.isEqual(to: window?.topController?.navigationIdentity))
        #expect(MockRootControllerNavigationIdentity().isEqual(to: window?.rootViewController?.navigationIdentity))
    }

    @Test
    func `Interception suffix is appended to navigation chain`() async {
        let authorizationService = TestAuthorizationService()
        let navigationInterceptor = MockNavigationInterceptor(authorizationService: authorizationService, kind: .suffixed)
        let navigator = Navigator(
            window: window,
            screenFactory: MockScreenFactory(),
            navigationInterceptor: navigationInterceptor
        )
        await preparePresented(navigator: navigator)
        let identity = SecretInformationIdentity()
        let requestedNavigation = expectation(description: "requested navigation")
        navigator.navigate(
            chain: [
                NavigationChainLink(
                    destination: .identity(identity),
                    strategy: .present(),
                    animated: false
                )
            ],
            completion: { _, _ in requestedNavigation.fulfill() }
        )

        await waitUntil("interception navigation", timeout: 10) {
            navigationInterceptor.interceptionIdentity.isEqual(to: window?.topController?.navigationIdentity)
                && navigationInterceptor.checkIsExists(reason: navigationInterceptor.interceptionReason)
        }

        #expect(!requestedNavigation.isFulfilled)
        #expect((window?.findController(destination: .identity(navigationInterceptor.interceptionIdentity))) != nil)
        #expect(!(identity.isEqual(to: window?.topController?.navigationIdentity)))
        #expect(navigationInterceptor.interceptionIdentity.isEqual(to: window?.topController?.navigationIdentity))
        #expect(navigationInterceptor.checkIsExists(reason: navigationInterceptor.interceptionReason))
        #expect(([navigationInterceptor.interceptionReason]) == (navigationInterceptor.getInterceptionReasons()))

        let expect1 = expectation(description: "navigation.resolved")
        navigationInterceptor.completion = { _, _ in taskDetachedMain { expect1.fulfill() } }
        authorizationService.authorize()

        await fulfillment(of: [requestedNavigation, expect1], timeout: 10)

        #expect((window?.findController(destination: .identity(navigationInterceptor.interceptionIdentity))) == nil)
        #expect((window?.findController(destination: .identity(identity))) != nil)
        #expect(identity.isEqual(to: window?.rootViewController?.navigationIdentity))
        #expect(MockPopControllerNavigationIdentity().isEqual(to: window?.topController?.navigationIdentity))
    }

    @Test
    func `Removes a specific interception reason`() async {
        let authorizationService = TestAuthorizationService()
        let navigationInterceptor = MockNavigationInterceptor(authorizationService: authorizationService)
        let navigator = Navigator(
            window: window,
            screenFactory: MockScreenFactory(),
            navigationInterceptor: navigationInterceptor
        )
        await preparePresented(navigator: navigator)
        let identity = SecretInformationIdentity()
        navigator.navigate(
            destination: .identity(identity),
            strategy: .present(),
            animated: false
        )

        await waitUntil("interception navigation", timeout: 10) {
            navigationInterceptor.interceptionIdentity.isEqual(to: window?.topController?.navigationIdentity)
                && navigationInterceptor.checkIsExists(reason: navigationInterceptor.interceptionReason)
        }

        #expect(!(identity.isEqual(to: window?.topController?.navigationIdentity)))
        #expect(navigationInterceptor.interceptionIdentity.isEqual(to: window?.topController?.navigationIdentity))
        #expect(navigationInterceptor.checkIsExists(reason: navigationInterceptor.interceptionReason))
        #expect(([navigationInterceptor.interceptionReason]) == (navigationInterceptor.getInterceptionReasons()))

        navigationInterceptor.removeIfAvailable(reason: navigationInterceptor.interceptionReason)

        #expect(!(navigationInterceptor.checkIsExists(reason: navigationInterceptor.interceptionReason)))
        #expect(([]) == (navigationInterceptor.getInterceptionReasons()))
    }

    @Test
    func `Removes all interception reasons`() async {
        let authorizationService = TestAuthorizationService()
        let navigationInterceptor = MockNavigationInterceptor(authorizationService: authorizationService)
        let navigator = Navigator(
            window: window,
            screenFactory: MockScreenFactory(),
            navigationInterceptor: navigationInterceptor
        )
        await preparePresented(navigator: navigator)
        let identity = SecretInformationIdentity()
        navigator.navigate(
            destination: .identity(identity),
            strategy: .present(),
            animated: false
        )

        await waitUntil("interception navigation", timeout: 10) {
            navigationInterceptor.interceptionIdentity.isEqual(to: window?.topController?.navigationIdentity)
                && navigationInterceptor.checkIsExists(reason: navigationInterceptor.interceptionReason)
        }

        #expect(!(identity.isEqual(to: window?.topController?.navigationIdentity)))
        #expect(navigationInterceptor.interceptionIdentity.isEqual(to: window?.topController?.navigationIdentity))
        #expect(navigationInterceptor.checkIsExists(reason: navigationInterceptor.interceptionReason))
        #expect(([navigationInterceptor.interceptionReason]) == (navigationInterceptor.getInterceptionReasons()))

        navigationInterceptor.removeAllReasons()

        #expect(!(navigationInterceptor.checkIsExists(reason: navigationInterceptor.interceptionReason)))
        #expect(([]) == (navigationInterceptor.getInterceptionReasons()))
    }

    func preparePresented(navigator: Navigator) async {
        let expect = expectation(description: "navigation.prepareNavigationStack")
        navigator.navigate(
            chain: [
                NavigationChainLink(
                    destination: .identity(MockRootControllerNavigationIdentity()),
                    strategy: .replaceWindowRoot(),
                    animated: false
                )
            ],
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        await fulfillment(of: [expect], timeout: 10)
    }

    @Test
    func `Interception results compare by value`() async {
        let link = NavigationChainLink(
            destination: .identity(MainNavigationIdentity()),
            strategy: .push(),
            animated: true
        )
        let reason = "Reason"
        let sut = NavigationInterceptionResult(
            link: link,
            event: ResponderMockEvent(),
            reason: reason
        )
        let expected = NavigationInterceptionResult(
            chain: [link],
            event: ResponderMockEvent(),
            reason: reason
        )

        #expect((sut.chain.count) == (expected.chain.count))
        #expect((true) == (sut.chain.first?.isEqual(to: expected.chain.first)))
        #expect((String(describing: sut.event)) == (String(describing: expected.event)))
        #expect((sut.reason) == (expected.reason))
    }

    @Test
    func `Releasing navigator removes intercepted navigation and destination`() async {
        let navigationInterceptor = RepeatedReasonNavigationInterceptor()
        weak var releasedNavigator: Navigator?
        weak var releasedController: UIViewController?
        await Task {
            let navigator = Navigator(
                window: window,
                screenFactory: MockScreenFactory(),
                navigationInterceptor: navigationInterceptor
            )
            let controller = UIViewController()
            releasedNavigator = navigator
            releasedController = controller

            navigator.navigate(
                destination: .controller(controller),
                strategy: .replaceWindowRoot(),
                animated: false
            )
            await waitUntil("intercepted navigation", timeout: 10) {
                navigationInterceptor.checkIsExists(reason: navigationInterceptor.reason)
            }
            #expect((releasedController) != nil)
            #expect(([navigationInterceptor.reason]) == (navigationInterceptor.getInterceptionReasons()))
        }.value

        #expect((releasedNavigator) == nil)
        #expect((releasedController) == nil)
        #expect(([]) == (navigationInterceptor.getInterceptionReasons()))
    }
}

class MockEmptyInterceptor: NavigationInterceptor {}

private struct RepeatedReasonNavigationEvent: ResponderEvent {}

private final class InterceptionTrackingViewController: UIViewController, Responder {
    var nextEventResponder: (any Responder)?
    private(set) var handledEventCount = 0

    func handle(event: any ResponderEvent) async -> Bool {
        guard event is RepeatedReasonNavigationEvent else { return false }

        handledEventCount += 1

        return true
    }
}

private final class RepeatedReasonNavigationInterceptor: NavigationInterceptor {
    let reason = "RepeatedReason"
    private var isResolved = false

    override func intercept(destination: NavigationDestination) -> NavigationInterceptionResult? {
        guard !isResolved else { return nil }

        return NavigationInterceptionResult(chain: [], reason: reason)
    }

    func resolve(
        newStrategy: NavigationStrategy? = nil,
        completion: ((UIViewController?, Bool) -> Void)?
    ) {
        isResolved = true
        interceptionResolved(
            reason: reason,
            newStrategy: newStrategy,
            completion: completion
        )
    }
}

private final class InterceptionOrderScreenFactory: MockScreenFactory {
    private(set) var trackedAssemblies: [String] = []

    override func assembleScreen(identity: any NavigationIdentity, navigator: Navigator) -> UIViewController {
        if identity is LoginNavigationIdentity {
            trackedAssemblies.append("interception")
        } else if identity is MockControllerNavigationIdentity {
            trackedAssemblies.append("queued")
        }

        return super.assembleScreen(identity: identity, navigator: navigator)
    }
}

private final class QueuingNavigationInterceptor: NavigationInterceptor {
    weak var navigator: Navigator?
    var onQueuedNavigationCompleted: (() -> Void)?

    private var hasQueuedNavigation = false

    override func intercept(destination: NavigationDestination) -> NavigationInterceptionResult? {
        guard !hasQueuedNavigation else {
            return nil
        }

        switch destination {
        case let .identity(identity) where identity is SecretInformationIdentity:
            hasQueuedNavigation = true
            navigator?.navigate(
                destination: .identity(MockControllerNavigationIdentity()),
                strategy: .replaceWindowRoot(),
                animated: false,
                completion: { [weak self] _, _ in
                    self?.onQueuedNavigationCompleted?()
                }
            )

            return NavigationInterceptionResult(
                link: NavigationChainLink(
                    destination: .identity(LoginNavigationIdentity()),
                    strategy: .present(),
                    animated: false
                ),
                reason: "QueuedNavigation"
            )
        default:
            return nil
        }
    }
}

private final class MockNavigationInterceptor: NavigationInterceptor {
    enum Kind {
        case prefixed
        case suffixed
        case replace
    }

    let authorizationService: TestAuthorizationService
    let interceptionIdentity = LoginNavigationIdentity()
    let interceptionReason = LoginRequiredNavigationInterceptionReason()
    var completion: ((UIViewController?, Bool) -> Void)?
    let kind: Kind

    init(authorizationService: TestAuthorizationService, kind: Kind = .replace) {
        self.authorizationService = authorizationService
        self.kind = kind

        super.init()

        authorizationService.onAuthorization = { [weak self] in
            self?.onAuthorized()
        }
    }

    override func intercept(destination: NavigationDestination) -> NavigationInterceptionResult? {
        switch destination {
        case let .identity(identity):
            if identity is (any LoginedOnlyNavigationIdentity) {
                if authorizationService.isAuthorized {
                    return nil
                } else {
                    return NavigationInterceptionResult(
                        chain: [
                            NavigationChainLink(
                                destination: .identity(interceptionIdentity),
                                strategy: .present(),
                                animated: true
                            )
                        ],
                        reason: interceptionReason
                    )
                }
            } else {
                return nil
            }
        case .controller:
            return nil
        }
    }

    private func onAuthorized() {
        switch kind {
        case .prefixed:
            interceptionResolved(
                reason: interceptionReason,
                prefixNavigationChain: [
                    NavigationChainLink(
                        destination: .identity(interceptionIdentity),
                        strategy: .closeIfTop(),
                        animated: true
                    )
                ],
                completion: completion
            )
        case .suffixed:
            interceptionResolved(
                reason: interceptionReason,
                newStrategy: .replaceWindowRoot(),
                suffixNavigationChain: [
                    NavigationChainLink(
                        destination: .identity(MockPopControllerNavigationIdentity()),
                        strategy: .present(),
                        animated: true
                    )
                ],
                completion: completion
            )
        case .replace:
            let transition = CATransition()
            transition.duration = 0.5
            transition.type = .fade
            interceptionResolved(
                reason: interceptionReason,
                newStrategy: .replaceWindowRoot(transition: transition),
                completion: completion
            )
        }
    }
}
