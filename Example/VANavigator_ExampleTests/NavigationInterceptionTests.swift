//
//  NavigationInterceptionTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 16.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import ObservationTracking
import UIKit
import VANavigator
import XCTest

@testable import VANavigator_Example

class NavigationInterceptionTests: XCTestCase {
    var window: UIWindow?

    override func setUp() async throws {
        window = UIWindow()
    }

    override func tearDown() async throws {
        window = nil
    }

    func test_defaultInterception() {
        let sut = MockEmptyInterceptor()

        XCTAssertNil(sut.intercept(destination: .identity(MockControllerNavigationIdentity())))
    }

    func test_navigationInterception() {
        let authorizationService = AuthorizationService()
        let navigationInterceptor = MockNavigationInterceptor(authorizationService: authorizationService)
        let navigator = Navigator(
            window: window,
            screenFactory: MockScreenFactory(),
            navigationInterceptor: navigationInterceptor
        )
        preparePresented(navigator: navigator)
        let identity = SecretInformationIdentity()
        let expect = expectation(description: "navigation.present")
        navigator.navigate(
            destination: .identity(identity),
            strategy: .present(),
            animated: false,
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertFalse(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(navigationInterceptor.interceptionIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(navigationInterceptor.checkIsExists(reason: navigationInterceptor.interceptionReason))
        XCTAssertEqual([navigationInterceptor.interceptionReason], navigationInterceptor.getInterceptionReasons())

        let expect1 = expectation(description: "navigation.resolved")
        navigationInterceptor.completion = { _, _ in taskDetachedMain { expect1.fulfill() } }
        authorizationService.authorize()

        wait(for: [expect1], timeout: 10)

        XCTAssertTrue(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(identity.isEqual(to: window?.rootViewController?.navigationIdentity))
    }

    func test_navigationInterception_assignedAfterInit() {
        let authorizationService = AuthorizationService()
        let navigationInterceptor = MockNavigationInterceptor(authorizationService: authorizationService)
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        navigator.navigationInterceptor = navigationInterceptor
        preparePresented(navigator: navigator)
        let identity = SecretInformationIdentity()
        let expect = expectation(description: "navigation.present")
        navigator.navigate(
            destination: .identity(identity),
            strategy: .present(),
            animated: false,
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertFalse(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(navigationInterceptor.interceptionIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(navigationInterceptor.checkIsExists(reason: navigationInterceptor.interceptionReason))

        let expect1 = expectation(description: "navigation.resolved")
        navigationInterceptor.completion = { _, _ in taskDetachedMain { expect1.fulfill() } }
        authorizationService.authorize()

        wait(for: [expect1], timeout: 10)

        XCTAssertTrue(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(identity.isEqual(to: window?.rootViewController?.navigationIdentity))
    }

    func test_navigationInterception_startsInterceptionChainBeforeQueuedNavigation() {
        let screenFactory = InterceptionOrderScreenFactory()
        let navigationInterceptor = QueuingNavigationInterceptor()
        let navigator = Navigator(
            window: window,
            screenFactory: screenFactory,
            navigationInterceptor: navigationInterceptor
        )
        navigationInterceptor.navigator = navigator
        preparePresented(navigator: navigator)

        let expect = expectation(description: "navigation.interception")
        let queuedExpect = expectation(description: "navigation.queued")
        navigationInterceptor.onQueuedNavigationCompleted = {
            taskDetachedMain { queuedExpect.fulfill() }
        }
        navigator.navigate(
            destination: .identity(SecretInformationIdentity()),
            strategy: .present(),
            animated: false,
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect, queuedExpect], timeout: 10)

        XCTAssertEqual(["interception", "queued"], screenFactory.trackedAssemblies)
    }

    func test_navigationInterception_resumesEveryNavigationWithTheSameReasonInFIFOOrder() {
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

        wait(for: [firstIntercepted, secondIntercepted], timeout: 10)

        XCTAssertEqual([navigationInterceptor.reason], navigationInterceptor.getInterceptionReasons())

        let resolved = expectation(description: "interceptions resolved")
        var result: Bool?
        navigationInterceptor.resolve { _, isSuccess in
            result = isSuccess
            resolved.fulfill()
        }

        wait(for: [resolved], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertEqual(1, firstController.handledEventCount)
        XCTAssertEqual(1, secondController.handledEventCount)
        XCTAssertIdentical(secondController, window?.rootViewController)
    }

    func test_navigationInterception_sharedInterceptorResumesInOriginatingNavigators() {
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

        wait(for: [firstIntercepted, secondIntercepted], timeout: 10)

        let resolved = expectation(description: "interceptions resolved")
        var completedController: UIViewController?
        var result: Bool?
        navigationInterceptor.resolve { controller, isSuccess in
            completedController = controller
            result = isSuccess
            resolved.fulfill()
        }

        wait(for: [resolved], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertIdentical(secondController, completedController)
        XCTAssertIdentical(firstController, firstWindow.rootViewController)
        XCTAssertIdentical(secondController, secondWindow.rootViewController)
        XCTAssertEqual(1, firstController.handledEventCount)
        XCTAssertEqual(1, secondController.handledEventCount)
    }

    func test_navigationInterception_strategyOverrideDoesNotMutateOriginalLink() {
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

        wait(for: [intercepted], timeout: 10)

        let resolved = expectation(description: "interception resolved")
        var result: Bool?
        navigationInterceptor.resolve(newStrategy: .replaceWindowRoot()) { _, isSuccess in
            result = isSuccess
            resolved.fulfill()
        }

        wait(for: [resolved], timeout: 10)

        XCTAssertEqual(true, result)
        XCTAssertIdentical(controller, window?.rootViewController)
        XCTAssertIdentical(originalStrategy, link.strategy)
    }

    func test_navigationInterception_prefixedNavigationChain() {
        let authorizationService = AuthorizationService()
        let navigationInterceptor = MockNavigationInterceptor(authorizationService: authorizationService, kind: .prefixed)
        let navigator = Navigator(
            window: window,
            screenFactory: MockScreenFactory(),
            navigationInterceptor: navigationInterceptor
        )
        preparePresented(navigator: navigator)
        let identity = SecretInformationIdentity()
        let expect = expectation(description: "navigation.present")
        navigator.navigate(
            chain: [
                NavigationChainLink(
                    destination: .identity(identity),
                    strategy: .present(),
                    animated: false
                )
            ],
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertNotNil(window?.findController(destination: .identity(navigationInterceptor.interceptionIdentity)))
        XCTAssertFalse(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(navigationInterceptor.interceptionIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(navigationInterceptor.checkIsExists(reason: navigationInterceptor.interceptionReason))
        XCTAssertEqual([navigationInterceptor.interceptionReason], navigationInterceptor.getInterceptionReasons())

        let expect1 = expectation(description: "navigation.resolved")
        navigationInterceptor.completion = { _, _ in taskDetachedMain { expect1.fulfill() } }
        authorizationService.authorize()

        wait(for: [expect1], timeout: 10)

        XCTAssertNil(window?.findController(destination: .identity(navigationInterceptor.interceptionIdentity)))
        XCTAssertTrue(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(MockRootControllerNavigationIdentity().isEqual(to: window?.rootViewController?.navigationIdentity))
    }

    func test_navigationInterception_suffixedNavigationChain() {
        let authorizationService = AuthorizationService()
        let navigationInterceptor = MockNavigationInterceptor(authorizationService: authorizationService, kind: .suffixed)
        let navigator = Navigator(
            window: window,
            screenFactory: MockScreenFactory(),
            navigationInterceptor: navigationInterceptor
        )
        preparePresented(navigator: navigator)
        let identity = SecretInformationIdentity()
        let expect = expectation(description: "navigation.present")
        navigator.navigate(
            chain: [
                NavigationChainLink(
                    destination: .identity(identity),
                    strategy: .present(),
                    animated: false
                )
            ],
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertNotNil(window?.findController(destination: .identity(navigationInterceptor.interceptionIdentity)))
        XCTAssertFalse(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(navigationInterceptor.interceptionIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(navigationInterceptor.checkIsExists(reason: navigationInterceptor.interceptionReason))
        XCTAssertEqual([navigationInterceptor.interceptionReason], navigationInterceptor.getInterceptionReasons())

        let expect1 = expectation(description: "navigation.resolved")
        navigationInterceptor.completion = { _, _ in taskDetachedMain { expect1.fulfill() } }
        authorizationService.authorize()

        wait(for: [expect1], timeout: 10)

        XCTAssertNil(window?.findController(destination: .identity(navigationInterceptor.interceptionIdentity)))
        XCTAssertNotNil(window?.findController(destination: .identity(identity)))
        XCTAssertTrue(identity.isEqual(to: window?.rootViewController?.navigationIdentity))
        XCTAssertTrue(MockPopControllerNavigationIdentity().isEqual(to: window?.topController?.navigationIdentity))
    }

    func test_navigationInterception_removeReason() {
        let authorizationService = AuthorizationService()
        let navigationInterceptor = MockNavigationInterceptor(authorizationService: authorizationService)
        let navigator = Navigator(
            window: window,
            screenFactory: MockScreenFactory(),
            navigationInterceptor: navigationInterceptor
        )
        preparePresented(navigator: navigator)
        let identity = SecretInformationIdentity()
        let expect = expectation(description: "navigation.present")
        navigator.navigate(
            destination: .identity(identity),
            strategy: .present(),
            animated: false,
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertFalse(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(navigationInterceptor.interceptionIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(navigationInterceptor.checkIsExists(reason: navigationInterceptor.interceptionReason))
        XCTAssertEqual([navigationInterceptor.interceptionReason], navigationInterceptor.getInterceptionReasons())

        navigationInterceptor.removeIfAvailable(reason: navigationInterceptor.interceptionReason)

        XCTAssertFalse(navigationInterceptor.checkIsExists(reason: navigationInterceptor.interceptionReason))
        XCTAssertEqual([], navigationInterceptor.getInterceptionReasons())
    }

    func test_navigationInterception_removeReasons() {
        let authorizationService = AuthorizationService()
        let navigationInterceptor = MockNavigationInterceptor(authorizationService: authorizationService)
        let navigator = Navigator(
            window: window,
            screenFactory: MockScreenFactory(),
            navigationInterceptor: navigationInterceptor
        )
        preparePresented(navigator: navigator)
        let identity = SecretInformationIdentity()
        let expect = expectation(description: "navigation.present")
        navigator.navigate(
            destination: .identity(identity),
            strategy: .present(),
            animated: false,
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertFalse(identity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(navigationInterceptor.interceptionIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertTrue(navigationInterceptor.checkIsExists(reason: navigationInterceptor.interceptionReason))
        XCTAssertEqual([navigationInterceptor.interceptionReason], navigationInterceptor.getInterceptionReasons())

        navigationInterceptor.removeAllReasons()

        XCTAssertFalse(navigationInterceptor.checkIsExists(reason: navigationInterceptor.interceptionReason))
        XCTAssertEqual([], navigationInterceptor.getInterceptionReasons())
    }

    func preparePresented(navigator: Navigator) {
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

        wait(for: [expect], timeout: 10)
    }

    func test_resultInit_equality() {
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

        XCTAssertEqual(sut.chain.count, expected.chain.count)
        XCTAssertEqual(true, sut.chain.first?.isEqual(to: expected.chain.first))
        XCTAssertEqual(String(describing: sut.event), String(describing: expected.event))
        XCTAssertEqual(sut.reason, expected.reason)
    }

    func test_releasedNavigator_removesInterceptedNavigationAndDestination() {
        let navigationInterceptor = RepeatedReasonNavigationInterceptor()
        weak var releasedNavigator: Navigator?
        weak var releasedController: UIViewController?

        autoreleasepool {
            let navigator = Navigator(
                window: window,
                screenFactory: MockScreenFactory(),
                navigationInterceptor: navigationInterceptor
            )
            let controller = UIViewController()
            releasedNavigator = navigator
            releasedController = controller
            let expect = expectation(description: "navigation.intercepted")

            navigator.navigate(
                destination: .controller(controller),
                strategy: .replaceWindowRoot(),
                animated: false,
                completion: { _, _ in expect.fulfill() }
            )

            wait(for: [expect], timeout: 10)
            XCTAssertNotNil(releasedController)
            XCTAssertEqual([navigationInterceptor.reason], navigationInterceptor.getInterceptionReasons())
        }

        XCTAssertNil(releasedNavigator)
        XCTAssertNil(releasedController)
        XCTAssertEqual([], navigationInterceptor.getInterceptionReasons())
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

class MockNavigationInterceptor: NavigationInterceptor {
    enum Kind {
        case prefixed
        case suffixed
        case replace
    }

    let authorizationService: AuthorizationService
    let interceptionIdentity = LoginNavigationIdentity()
    let interceptionReason = LoginRequiredNavigationInterceptionReason()
    var completion: ((UIViewController?, Bool) -> Void)?
    let kind: Kind

    init(authorizationService: AuthorizationService, kind: Kind = .replace) {
        self.authorizationService = authorizationService
        self.kind = kind

        super.init()

        bind()
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

    @ObservationTracking
    private func bind() {
        if authorizationService.isAuthorized {
            onAuthorized()
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
                    ),
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
