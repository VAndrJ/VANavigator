//
//  ScreenFactory.swift
//  SimpleExample
//
//  Created by VAndrJ on 13.02.2024.
//

import UIKit

class ScreenFactory: NavigatorScreenFactory {
    let authorizationService: ExampleAuthorizationService

    init(authorizationService: ExampleAuthorizationService) {
        self.authorizationService = authorizationService
    }

    // swiftlint:disable:next function_body_length
    func assembleScreen(identity: any NavigationIdentity, navigator: Navigator) -> UIViewController {
        switch identity {
        case _ as TabPresentExampleNavigationIdentity:
            // TODO: - own view
            return assembleScreen(identity: MainNavigationIdentity(), navigator: navigator).apply {
                $0.tabBarItem = .init(
                    title: "Present",
                    image: .init(systemName: "p.circle"),
                    selectedImage: nil
                )
            }
        case let identity as NavNavigationIdentity:
            return NavigationController(controllers: identity.children.map { identity in
                assembleScreen(identity: identity, navigator: navigator).apply {
                    $0.navigationIdentity = identity
                }
            })
        case let identity as TabNavigationIdentity:
            return TabBarController(controllers: identity.children.map { identity in
                assembleScreen(identity: identity, navigator: navigator).apply {
                    $0.navigationIdentity = identity
                }
            }).apply {
                $0.tabBar.backgroundColor = .yellow
            }
        case _ as MainNavigationIdentity:
            return MainScreenView(viewModel: .init(data: .init(
                related: .init(),
                source: .init(),
                navigation: .init(
                    followReplaceRootWithNewMain: navigator ?> { replaceRoot(navigator: $0) },
                    followPushOrPresentDetails: navigator ?> {
                        let identity = DetailsNavigationIdentity(number: -1)
                        $0.navigate(
                            destination: .identity(identity),
                            strategy: .popToExisting(),
                            fallback: .init(
                                destination: .identity(identity),
                                strategy: .present(),
                                animated: true
                            )
                        )
                    },
                    followReplaceRootWithTabs: navigator ?> {
                        $0.navigate(
                            destination: .identity(TabNavigationIdentity(children: [
                                MainNavigationIdentity(),
                                TabPresentExampleNavigationIdentity(),
                            ])),
                            strategy: .replaceWindowRoot()
                        )
                    },
                    followLoginedOnlyContent: navigator ?> {
                        $0.navigate(
                            destination: .identity(SecretInformationIdentity()),
                            strategy: .present()
                        )
                    }
                )
            ))).embedded(tabBarItem: .init(
                title: "Main",
                image: .init(systemName: "house"),
                selectedImage: nil
            ))
        case let identity as DetailsNavigationIdentity:
            return DetailsScreenView(viewModel: .init(data: .init(
                related: .init(number: identity.number),
                source: .init(),
                navigation: .init(
                    followReplaceRootWithNewMain: navigator ?> { replaceRoot(navigator: $0) },
                    followCloseIfTopPushedOrPresented: navigator ?> {
                        $0.navigate(
                            destination: .identity(identity),
                            strategy: .closeIfTop(),
                            animated: true
                        )
                    }
                )
            ))).embedded
        case _ as LoginNavigationIdentity:
            return LoginScreenView(viewModel: .init(data: .init(
                related: .init(),
                source: .init(authorize: authorizationService ?>> { $0.authorize }),
                navigation: .init()
            ))).embedded
        case _ as SecretInformationIdentity:
            return SecretInformationScreenView(viewModel: .init(data: .init(
                related: .init(),
                source: .init(),
                navigation: .init(
                    followReplaceRootWithNewMain: navigator ?> { replaceRoot(navigator: $0) }
                )
            ))).embedded
        default:
            assertionFailure("Not implemented \(type(of: identity))")

            return UIViewController()
        }
    }
}

@MainActor
private func replaceRoot(navigator: Navigator?) {
    guard let navigator else { return }

    let transition = CATransition()
    transition.duration = 0.3
    transition.type = .reveal
    navigator.navigate(
        destination: .identity(MainNavigationIdentity()),
        strategy: .replaceWindowRoot(transition: transition)
    )
}
