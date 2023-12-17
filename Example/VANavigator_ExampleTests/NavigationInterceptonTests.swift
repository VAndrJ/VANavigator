//
//  NavigationInterceptonTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 16.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import XCTest
import VANavigator
import RxSwift
import RxCocoa
@testable import VANavigator_Example

@MainActor
class NavigationInterceptonTests: XCTestCase {
    var window: UIWindow?

    override func setUp() {
        window = UIWindow()
    }

    override func tearDown() {
        window = nil
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
            strategy: .present,
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
                    strategy: .present,
                    animated: false
                ),
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
                    strategy: .present,
                    animated: false
                ),
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
            strategy: .present,
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
            strategy: .present,
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
                    strategy: .present,
                    animated: false
                ),
            ],
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)
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
    var completion: (((UIViewController & Responder)?, Bool) -> Void)?
    let kind: Kind

    private let bag = DisposeBag()

    init(authorizationService: AuthorizationService, kind: Kind = .replace) {
        self.authorizationService = authorizationService
        self.kind = kind

        super.init()

        bind()
    }

    override func intercept(destination: NavigationDestination) -> NavigationInterceptionResult? {
        switch destination {
        case let .identity(identity):
            if identity is LoginedOnlyNavigationIdentity {
                if authorizationService.isAuthorized {
                    return nil
                } else {
                    return NavigationInterceptionResult(
                        chain: [
                            NavigationChainLink(
                                destination: .identity(interceptionIdentity),
                                strategy: .present,
                                animated: true
                            ),
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

    private func bind() {
        authorizationService.isAuthorizedObs
            .filter { $0 }
            .subscribe(onNext: self ?> { $0.onAuthorized() })
            .disposed(by: bag)
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
                    NavigationChainLink(
                        destination: .identity(MockNavControllerNavigationIdentity(children: [])),
                        strategy: .closeIfTop(),
                        animated: true
                    ),
                    NavigationChainLink(
                        destination: .identity(MockPopControllerNavigationIdentity()),
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
                        strategy: .present,
                        animated: true
                    ),
                ],
                completion: completion
            )
        case .replace:
            interceptionResolved(
                reason: interceptionReason,
                newStrategy: .replaceWindowRoot(transition: CATransition().apply {
                    $0.duration = 0.5
                    $0.type = .fade
                }),
                completion: completion
            )
        }
    }
}
