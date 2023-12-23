//
//  ExampleNavigationInterceptor.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 04.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import VATextureKitRx
import VANavigator

struct LoginRequiredNavigationInterceptionReason: Hashable {}

class ExampleNavigationInterceptor: NavigationInterceptor {
    let authorizationService: AuthorizationService
    var completion: ((UIViewController?, Bool) -> Void)?

    private let bag = DisposeBag()

    init(authorizationService: AuthorizationService) {
        self.authorizationService = authorizationService

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

    private func bind() {
        authorizationService.isAuthorizedObs
            .filter { $0 }
            .subscribe(onNext: self ?> { $0.onAuthorized() })
            .disposed(by: bag)
    }

    private func onAuthorized() {
        interceptionResolved(
            reason: LoginRequiredNavigationInterceptionReason(),
            newStrategy: .replaceWindowRoot(transition: CATransition().apply {
                $0.duration = 0.5
                $0.type = .fade
            }),
            completion: completion
        )
    }
}
