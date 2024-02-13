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

    func assembleScreen(identity: NavigationIdentity, navigator: Navigator) -> UIViewController {
        switch identity {
        case _ as TabPresentExampleNavigationIdentity:
            // TODO: -
            return assembleScreen(identity: MainNavigationIdentity(), navigator: navigator).apply {
                $0.tabBarItem = UITabBarItem(
                    title: "Present",
                    image: UIImage(systemName: "p.circle"),
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
            return ViewController(view: MainScreenView(viewModel: .init(data: .init(
                related: .init(),
                source: .init(),
                navigation: .init(
                    followReplaceRootWithNewMain: self ?> { [weak navigator] in $0.replaceRoot(navigator: navigator) },
                    followPushOrPresentDetails: navigator ?> {
                        let identity = DetailsNavigationIdentity(number: -1)
                        $0.navigate(
                            destination: .identity(identity),
                            strategy: .popToExisting(),
                            fallback: NavigationChainLink(
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
            )))).apply {
                $0.tabBarItem = .init(
                    title: "Main",
                    image: UIImage(systemName: "house"),
                    selectedImage: nil
                )
            }
        case let identity as DetailsNavigationIdentity:
            return ViewController(view: DetailsScreenView(viewModel: .init(data: .init(
                related: .init(number: identity.number),
                source: .init(),
                navigation: .init(
                    followReplaceRootWithNewMain: self ?> { [weak navigator] in $0.replaceRoot(navigator: navigator) },
                    followCloseIfTopPushedOrPresented: navigator ?> {
                        $0.navigate(
                            destination: .identity(identity),
                            strategy: .closeIfTop(),
                            animated: true
                        )
                    }
                )
            ))))
        case _ as LoginNavigationIdentity:
            return ViewController(view: LoginScreenView(viewModel: .init(data: .init(
                related: .init(),
                source: .init(authorize: authorizationService ?>> { $0.authorize }),
                navigation: .init()
            ))))
        case _ as SecretInformationIdentity:
            return ViewController(view: SecretInformationScreenView(viewModel: .init(data: .init(
                related: .init(),
                source: .init(),
                navigation: .init(
                    followReplaceRootWithNewMain: self ?> { [weak navigator] in $0.replaceRoot(navigator: navigator) }
                )
            ))))
        default:
            assertionFailure("Not implemented \(type(of: identity))")

            return UIViewController()
        }
    }

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
}
