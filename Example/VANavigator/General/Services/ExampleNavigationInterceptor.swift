//
//  ExampleNavigationInterceptor.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 04.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Observation
import ObservationTracking
import Swiftional
import UIKit
import VANavigator

struct LoginRequiredNavigationInterceptionReason: Hashable {}

final class ExampleNavigationInterceptor: NavigationInterceptor {
    let authorizationService: AuthorizationService

    init(authorizationService: AuthorizationService) {
        self.authorizationService = authorizationService

        super.init()

        bind()
    }

    override func intercept(destination: NavigationDestination) -> NavigationInterceptionResult? {
        switch destination {
        case let .identity(identity):
            if identity is (any AuthorizedOnlyNavigationIdentity) {
                if authorizationService.isAuthorized {
                    return nil
                } else {
                    return NavigationInterceptionResult(
                        link: NavigationChainLink(
                            destination: .identity(LoginNavigationIdentity()),
                            strategy: .replaceWindowRoot(),
                            animated: true
                        ),
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

    @ObservationTracking
    private func bind() {
        if authorizationService.isAuthorized {
            onAuthorized()
        }
    }

    private func onAuthorized() {
        interceptionResolved(
            reason: LoginRequiredNavigationInterceptionReason(),
            newStrategy: .replaceWindowRoot(
                transition: CATransition().apply {
                    $0.duration = 0.5
                    $0.type = .fade
                }
            ),
            completion: nil
        )
    }
}
