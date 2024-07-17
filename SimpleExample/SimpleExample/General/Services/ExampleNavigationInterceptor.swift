//
//  ExampleNavigationInterceptor.swift
//  SimpleExample
//
//  Created by VAndrJ on 13.02.2024.
//

import UIKit

struct LoginRequiredNavigationInterceptionReason: Hashable {}

final class ExampleNavigationInterceptor: NavigationInterceptor {
    let authorizationService: ExampleAuthorizationService
    var completion: ((UIViewController?, Bool) -> Void)?

    init(authorizationService: ExampleAuthorizationService) {
        self.authorizationService = authorizationService

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
                                destination: .identity(LoginNavigationIdentity()),
                                strategy: .replaceWindowRoot(),
                                animated: true
                            ),
                        ],
                        reason: LoginRequiredNavigationInterceptionReason()
                    )
                }
            } else {
                return nil
            }
        case .controller:
            return nil
        }
    }

    private func onAuthorizationChanged(_ isAuthorized: Bool) {
        guard isAuthorized else { return }
        
        interceptionResolved(
            reason: LoginRequiredNavigationInterceptionReason(),
            newStrategy: .replaceWindowRoot(transition: CATransition().apply {
                $0.duration = 0.5
                $0.type = .fade
            }),
            completion: completion
        )
    }

    private func bind() {
        authorizationService.onAuthorizationChanged = self ?>> { $0.onAuthorizationChanged(_:) }
    }
}
