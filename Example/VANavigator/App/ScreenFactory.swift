//
//  ScreenFactory.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import VATextureKit

// swiftlint:disable type_body_length
class ScreenFactory: NavigatorScreenFactory {
    let authorizationService: AuthorizationService

    init(authorizationService: AuthorizationService) {
        self.authorizationService = authorizationService
    }

    // swiftlint:disable function_body_length cyclomatic_complexity
    func assembleScreen(identity: NavigationIdentity, navigator: Navigator) -> UIViewController {
        switch identity {
        case _ as TabPresentExampleNavigationIdentity:
            return ViewController(
                node: TabPresentExampleControllerNode(viewModel: .init(data: .init(
                    navigation: .init(
                        followPresentFromTop: { [weak navigator] in
                            navigator?.navigate(
                                destination: .controller(UIViewController().apply {
                                    $0.view.backgroundColor = .blue.withAlphaComponent(0.3)
                                    $0.modalPresentationStyle = .overCurrentContext
                                }),
                                strategy: .present(),
                                completion: { controller, _ in
                                    if let controller {
                                        mainAsync(after: 1) {
                                            navigator?.navigate(
                                                destination: .controller(controller),
                                                strategy: .closeIfTop()
                                            )
                                        }
                                    }
                                }
                            )
                        },
                        followPresentFromTab: { [weak navigator] in
                            navigator?.navigate(
                                destination: .controller(UIViewController().apply {
                                    $0.view.backgroundColor = .green.withAlphaComponent(0.3)
                                    $0.modalPresentationStyle = .overCurrentContext
                                }),
                                strategy: .present(source: .tabBarController),
                                completion: { controller, _ in
                                    if let controller {
                                        mainAsync(after: 1) {
                                            navigator?.navigate(
                                                destination: .controller(controller),
                                                strategy: .closeIfTop()
                                            )
                                        }
                                    }
                                }
                            )
                        }
                    )
                ))),
                shouldHideNavigationBar: false
            ).apply {
                $0.tabBarItem = UITabBarItem(
                    title: "Present",
                    image: UIImage(systemName: "p.circle"),
                    selectedImage: nil
                )
            }
        case let identity as NavNavigationIdentity:
            let controller = NavigationController()
            let viewControllers = identity.children.map { identity in
                let controller = assembleScreen(identity: identity, navigator: navigator)
                controller.navigationIdentity = identity

                return controller
            }
            controller.setViewControllers(viewControllers, animated: false)

            return controller
        case let identity as TabNavigationIdentity:
            let controller = VATabBarController()
            let tabControllers = identity.children.map { identity in
                let controller = assembleScreen(identity: identity, navigator: navigator)
                controller.navigationIdentity = identity

                return NavigationController(controller: controller)
            }
            controller.setViewControllers(tabControllers, animated: false)
            controller.tabBar.backgroundColor = .yellow

            return controller
        case _ as MainNavigationIdentity:
            return ViewController(
                node: MainControllerNode(viewModel: .init(data: .init(
                    source: .init(
                        authorizedObs: authorizationService.isAuthorizedObs
                    ),
                    navigation: .init(
                        followReplaceRootWithNewMain: { [weak navigator] in
                            let transition = CATransition()
                            transition.duration = 0.3
                            transition.type = .reveal
                            navigator?.navigate(
                                destination: .identity(MainNavigationIdentity()),
                                strategy: .replaceWindowRoot(transition: transition)
                            )
                        },
                        followPushOrPresentDetails: { [weak navigator] in
                            let identity = DetailsNavigationIdentity(number: -1)
                            navigator?.navigate(
                                destination: .identity(identity),
                                strategy: .popToExisting(),
                                fallback: NavigationChainLink(
                                    destination: .identity(NavNavigationIdentity(children: [
                                        identity,
                                    ])),
                                    strategy: .present(),
                                    animated: true
                                )
                            )
                        },
                        followTabs: { [weak navigator] in
                            navigator?.navigate(
                                destination: .identity(TabNavigationIdentity(children: [
                                    TabDetailNavigationIdentity(),
                                    MoreNavigationIdentity(),
                                    TabPresentExampleNavigationIdentity(),
                                ])),
                                strategy: .closeToExisting,
                                fallbackStrategies: [.replaceWindowRoot()]
                            )
                        },
                        followSplit: { [weak navigator] in
                            let destination: NavigationDestination = .identity(SplitNavigationIdentity(
                                primary: PrimaryNavigationIdentity(),
                                secondary: MoreNavigationIdentity(),
                                supplementary: SecondaryNavigationIdentity()
                            ))
                            navigator?.navigate(
                                destination: destination,
                                strategy: .closeToExisting,
                                fallback: NavigationChainLink(
                                    destination: destination,
                                    strategy: .present(),
                                    animated: true
                                )
                            )
                        },
                        followShowInSplitOrPresent: {
                            let destination = DetailsNavigationIdentity(number: -1)
                            navigator.navigate(
                                destination: .identity(destination),
                                strategy: .split(strategy: .secondary(action: .replace)),
                                fallback: NavigationChainLink(
                                    destination: .identity(SplitNavigationIdentity(
                                        primary: PrimaryNavigationIdentity(),
                                        secondary: destination
                                    )),
                                    strategy: .present(),
                                    animated: true
                                )
                            )
                        },
                        followLoginedContent: {
                            navigator.navigate(
                                destination: .identity(SecretInformationIdentity()),
                                strategy: .present()
                            )
                        }
                    )
                )))
            )
        case _ as TabDetailNavigationIdentity:
            return ViewController(
                node: TabDetailControllerNode(viewModel: .init(data: .init(
                    navigation: .init(
                        followReplaceRootWithNewMain: { [weak navigator] in
                            let transition = CATransition()
                            transition.duration = 0.3
                            transition.type = .reveal
                            navigator?.navigate(
                                destination: .identity(MainNavigationIdentity()),
                                strategy: .replaceWindowRoot(transition: transition)
                            )
                        },
                        followPushOrPopNext: { [weak navigator] value in
                            navigator?.navigate(chain: value.map {
                                NavigationChainLink(
                                    destination: .identity(DetailsNavigationIdentity(number: $0)),
                                    strategy: .popToExisting(),
                                    animated: true,
                                    fallback: NavigationChainLink(
                                        destination: .identity(DetailsNavigationIdentity(number: $0)),
                                        strategy: .push,
                                        animated: true
                                    )
                                )
                            })
                        }
                    )
                ))),
                shouldHideNavigationBar: false
            ).apply {
                $0.tabBarItem = UITabBarItem(
                    title: "Tab details",
                    image: UIImage(systemName: "info.circle"),
                    selectedImage: nil
                )
            }
        case _ as MoreNavigationIdentity:
            return ViewController(
                node: MoreControllerNode(viewModel: .init(data: .init(
                    navigation: .init(
                        followReplaceRootWithNewMain: { [weak navigator] in
                            let transition = CATransition()
                            transition.duration = 0.3
                            transition.type = .reveal
                            navigator?.navigate(
                                destination: .identity(MainNavigationIdentity()),
                                strategy: .replaceWindowRoot(transition: transition)
                            )
                        }
                    )
                ))),
                shouldHideNavigationBar: false
            ).apply {
                $0.tabBarItem = UITabBarItem(
                    title: "More",
                    image: UIImage(systemName: "ellipsis.circle"),
                    selectedImage: nil
                )
            }
        case let identity as DetailsNavigationIdentity:
            return ViewController(
                node: DetailsToPresentControllerNode(viewModel: .init(data: .init(
                    related: .init(
                        value: identity.number
                    ),
                    navigation: .init(
                        followReplaceRootWithNewMain: { [weak navigator] in
                            let transition = CATransition()
                            transition.duration = 0.3
                            transition.type = .fade
                            navigator?.navigate(
                                destination: .identity(MainNavigationIdentity()),
                                strategy: .replaceWindowRoot(transition: transition)
                            )
                        },
                        followPushOrPopNext: { [weak navigator] value in
                            navigator?.navigate(chain: value.map {
                                NavigationChainLink(
                                    destination: .identity(DetailsNavigationIdentity(number: $0)),
                                    strategy: .popToExisting(),
                                    animated: true,
                                    fallback: NavigationChainLink(
                                        destination: .identity(DetailsNavigationIdentity(number: $0)),
                                        strategy: .push,
                                        animated: true
                                    )
                                )
                            })
                        }
                    )
                ))),
                shouldHideNavigationBar: false,
                isNotImportant: true
            )
        case let identity as SplitNavigationIdentity:
            let controller: UISplitViewController
            if identity.supplementary == nil {
                controller = UISplitViewController(style: .doubleColumn)
            } else {
                controller = UISplitViewController(style: .tripleColumn)
            }
            controller.preferredDisplayMode = .automatic
            controller.preferredSplitBehavior = .tile
            let primary = identity.primary
            let primaryController = assembleScreen(identity: primary, navigator: navigator)
            primaryController.navigationIdentity = primary
            controller.setViewController(primaryController, for: .primary)
            let secondary = identity.secondary
            let secondaryController = assembleScreen(identity: secondary, navigator: navigator)
            secondaryController.navigationIdentity = secondary
            controller.setViewController(secondaryController, for: .secondary)
            if let supplementary = identity.supplementary {
                let supplementaryController = assembleScreen(identity: supplementary, navigator: navigator)
                supplementaryController.navigationIdentity = supplementary
                controller.setViewController(supplementaryController, for: .supplementary)
            }
            controller.preferredPrimaryColumnWidthFraction = 0.33
            
            return controller
        case _ as PrimaryNavigationIdentity:
            return ViewController(
                node: PrimaryControllerNode(viewModel: .init(data: .init(
                    navigation: .init(
                        followReplaceRootWithNewMain: { [weak navigator] in
                            let transition = CATransition()
                            transition.duration = 0.3
                            transition.type = .reveal
                            navigator?.navigate(
                                destination: .identity(MainNavigationIdentity()),
                                strategy: .replaceWindowRoot(transition: transition)
                            )
                        },
                        followReplacePrimary: { [weak navigator] in
                            navigator?.navigate(
                                destination: .identity(PrimaryNavigationIdentity()),
                                strategy: .split(strategy: .primary(action: .replace)),
                                animated: false
                            )
                        },
                        followShowSplitSecondary: { [weak navigator] in
                            navigator?.navigate(
                                destination: .identity(SecondaryNavigationIdentity()),
                                strategy: .split(strategy: .secondary(action: .push))
                            )
                        },
                        followShowInSplitOrPresent: {
                            let destination = DetailsNavigationIdentity(number: -1)
                            navigator.navigate(
                                destination: .identity(destination),
                                strategy: .split(strategy: .secondary(action: .replace)),
                                fallback: NavigationChainLink(
                                    destination: .identity(SplitNavigationIdentity(
                                        primary: PrimaryNavigationIdentity(),
                                        secondary: destination
                                    )),
                                    strategy: .present(),
                                    animated: true
                                )
                            )
                        }
                    )
                ))),
                shouldHideNavigationBar: false
            )
        case _ as SecondaryNavigationIdentity:
            return ViewController(
                node: SecondaryControllerNode(viewModel: .init(data: .init(
                    navigation: .init(
                        followReplaceRootWithNewMain: { [weak navigator] in
                            let transition = CATransition()
                            transition.duration = 0.3
                            transition.type = .reveal
                            navigator?.navigate(
                                destination: .identity(MainNavigationIdentity()),
                                strategy: .replaceWindowRoot(transition: transition)
                            )
                        },
                        followShowSplitSecondary: { [weak navigator] in
                            navigator?.navigate(
                                destination: .identity(SecondaryNavigationIdentity()),
                                strategy: .split(strategy: .secondary(action: .push))
                            )
                        },
                        followShowInSplitOrPresent: {
                            let identity = DetailsNavigationIdentity(number: -1)
                            navigator.navigate(
                                destination: .identity(identity),
                                strategy: .split(strategy: .secondary(action: .replace)),
                                fallback: NavigationChainLink(
                                    destination: .identity(SplitNavigationIdentity(
                                        primary: PrimaryNavigationIdentity(),
                                        secondary: identity
                                    )),
                                    strategy: .present(),
                                    animated: true
                                )
                            )
                        }
                    )
                ))),
                shouldHideNavigationBar: false
            )
        case _ as LoginNavigationIdentity:
            return ViewController(
                node: LoginControllerNode(viewModel: .init(data: .init(
                    source: .init(authorize: { [weak authorizationService] in
                        authorizationService?.authorize()
                    }),
                    navigation: .init(followReplaceRootWithNewMain: { [weak navigator] in
                        let transition = CATransition()
                        transition.duration = 0.3
                        transition.type = .reveal
                        navigator?.navigate(
                            destination: .identity(MainNavigationIdentity()),
                            strategy: .replaceWindowRoot(transition: transition)
                        )
                    })
                ))),
                shouldHideNavigationBar: false
            )
        case _ as SecretInformationIdentity:
            return ViewController(
                node: SecretInformationControllerNode(viewModel: .init(data: .init(
                    navigation: .init(
                        followReplaceRootWithNewMain: { [weak navigator] in
                            let transition = CATransition()
                            transition.duration = 0.3
                            transition.type = .reveal
                            navigator?.navigate(
                                destination: .identity(MainNavigationIdentity()),
                                strategy: .replaceWindowRoot(transition: transition)
                            )
                        }
                    )
                ))),
                shouldHideNavigationBar: false
            )
        default:
            assertionFailure("Not implemented \(type(of: identity))")

            return UIViewController()
        }
    }
    // swiftlint:enable function_body_length cyclomatic_complexity
}
// swiftlint:enable type_body_length
