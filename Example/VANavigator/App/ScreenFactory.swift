//
//  ScreenFactory.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

final class ScreenFactory: NavigatorScreenFactory {
    let authorizationService: AuthorizationService

    init(authorizationService: AuthorizationService) {
        self.authorizationService = authorizationService
    }

    func assembleScreen(identity: any NavigationIdentity, navigator: Navigator) -> UIViewController {
        switch identity {
        case _ as QueueNavigationIdentity:
            return BaseViewController(
                screen: NavigationQueueExampleScreen(
                    viewModel: .init(
                        context: .init(
                            navigation: .init(
                                followReplaceRootWithNewMain: navigator ?> { replaceRoot(navigator: $0) },
                                followPresentAndClose: { [weak navigator] in
                                    for _ in 0..<$0 {
                                        navigator?.navigate(
                                            destination: .identity(MoreNavigationIdentity()),
                                            strategy: .present()
                                        )
                                        navigator?.navigate(
                                            destination: .identity(MoreNavigationIdentity()),
                                            strategy: .closeIfTop()
                                        )
                                    }
                                }
                            )
                        )
                    )
                )
            )
        case _ as TabPresentExampleNavigationIdentity:
            return BaseViewController(
                screen: TabPresentExampleScreen(
                    viewModel: .init(
                        context: .init(
                            navigation: .init(
                                followPresentFromTop: { [weak navigator] in
                                    navigator?.navigate(
                                        destination: .controller(
                                            UIViewController().apply {
                                                $0.view.backgroundColor = .blue.withAlphaComponent(0.3)
                                                $0.modalPresentationStyle = .overCurrentContext
                                            }
                                        ),
                                        strategy: .present(),
                                        completion: { controller, _ in
                                            if let controller {
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
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
                                        destination: .controller(
                                            UIViewController().apply {
                                                $0.view.backgroundColor = .green.withAlphaComponent(0.3)
                                                $0.modalPresentationStyle = .overCurrentContext
                                            }
                                        ),
                                        strategy: .present(source: .tabBarController),
                                        completion: { controller, _ in
                                            if let controller {
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                                    navigator?.navigate(
                                                        destination: .controller(controller),
                                                        strategy: .closeIfTop()
                                                    )
                                                }
                                            }
                                        }
                                    )
                                },
                                followPresentPopover: { [weak navigator] source in
                                    navigator?.navigate(
                                        destination: .identity(
                                            NavNavigationIdentity(children: [
                                                DetailsNavigationIdentity(number: 11),
                                                DetailsNavigationIdentity(number: 12),
                                            ])
                                        ),
                                        strategy: .popover(configure: { [weak source] popover, _ in
                                            popover.permittedArrowDirections = .up
                                            popover.sourceView = source
                                        })
                                    )
                                }
                            )
                        )
                    )
                ),
                shouldHideNavigationBar: false
            ).apply {
                $0.tabBarItem = UITabBarItem(
                    title: "Present",
                    image: UIImage(systemName: "p.circle"),
                    selectedImage: nil
                )
            }
        case let identity as NavNavigationIdentity:
            return NavigationController(
                controllers: identity.children.map { identity in
                    let controller = assembleScreen(identity: identity, navigator: navigator)
                    controller.navigationIdentity = identity

                    return controller
                }
            )
        case let identity as TabNavigationIdentity:
            let tabControllers = identity.children.map { identity in
                let controller = assembleScreen(identity: identity, navigator: navigator)
                controller.navigationIdentity = identity

                return NavigationController(controller: controller)
            }
            let controller = TabBarController(controllers: tabControllers)
            controller.setViewControllers(tabControllers, animated: false)
            controller.tabBar.backgroundColor = .yellow

            return controller
        case _ as MainNavigationIdentity:
            return BaseViewController(
                screen: MainScreen(
                    viewModel: .init(
                        context: .init(
                            source: .init(
                                authorizationService: authorizationService
                            ),
                            navigation: .init(
                                followReplaceRootWithNewMain: navigator ?> { replaceRoot(navigator: $0) },
                                followPushOrPresentDetails: { [weak navigator] in
                                    let identity = DetailsNavigationIdentity(number: -1)
                                    navigator?.navigate(
                                        destination: .identity(identity),
                                        strategy: .popToExisting(),
                                        fallback: NavigationChainLink(
                                            destination: .identity(
                                                NavNavigationIdentity(children: [
                                                    identity
                                                ])
                                            ),
                                            strategy: .present(),
                                            animated: true
                                        )
                                    )
                                },
                                followTabs: { [weak navigator] in
                                    navigator?.navigate(
                                        destination: .identity(
                                            TabNavigationIdentity(children: [
                                                TabDetailNavigationIdentity(),
                                                MoreNavigationIdentity(),
                                                TabPresentExampleNavigationIdentity(),
                                            ])
                                        ),
                                        strategy: .closeToExisting,
                                        fallbackStrategies: [.replaceWindowRoot()]
                                    )
                                },
                                followSplit: { [weak navigator] in
                                    let destination: NavigationDestination = .identity(
                                        SplitNavigationIdentity(
                                            primary: PrimaryNavigationIdentity(),
                                            secondary: MoreNavigationIdentity(),
                                            supplementary: SecondaryNavigationIdentity()
                                        )
                                    )
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
                                followShowInSplitOrPresent: { [weak navigator] in
                                    let destination = DetailsNavigationIdentity(number: -1)
                                    navigator?.navigate(
                                        destination: .identity(destination),
                                        strategy: .split(strategy: .secondary(action: .replace)),
                                        fallback: NavigationChainLink(
                                            destination: .identity(
                                                SplitNavigationIdentity(
                                                    primary: PrimaryNavigationIdentity(),
                                                    secondary: destination
                                                )
                                            ),
                                            strategy: .present(),
                                            animated: true
                                        )
                                    )
                                },
                                followLoginedContent: { [weak navigator] in
                                    navigator?.navigate(
                                        destination: .identity(SecretInformationIdentity()),
                                        strategy: .present()
                                    )
                                },
                                followQueue: { [weak navigator] in
                                    navigator?.navigate(
                                        destination: .identity(QueueNavigationIdentity()),
                                        strategy: .present()
                                    )
                                }
                            )
                        )
                    )
                )
            )
        case _ as TabDetailNavigationIdentity:
            return BaseViewController(
                screen: TabDetailScreen(
                    viewModel: .init(
                        context: .init(
                            navigation: .init(
                                followReplaceRootWithNewMain: navigator ?> { replaceRoot(navigator: $0) },
                                followPushOrPopNext: { [weak navigator] value in
                                    navigator?.navigate(
                                        chain: value.map {
                                            NavigationChainLink(
                                                destination: .identity(DetailsNavigationIdentity(number: $0)),
                                                strategy: .popToExisting(),
                                                animated: true,
                                                fallback: NavigationChainLink(
                                                    destination: .identity(DetailsNavigationIdentity(number: $0)),
                                                    strategy: .push(),
                                                    animated: true
                                                )
                                            )
                                        }
                                    )
                                }
                            )
                        )
                    )
                ),
                shouldHideNavigationBar: false
            ).apply {
                $0.tabBarItem = UITabBarItem(
                    title: "Tab details",
                    image: UIImage(systemName: "info.circle"),
                    selectedImage: nil
                )
            }
        case _ as MoreNavigationIdentity:
            return BaseViewController(
                screen: MoreScreen(
                    viewModel: .init(
                        context: .init(
                            navigation: .init(
                                followReplaceRootWithNewMain: navigator ?> { replaceRoot(navigator: $0) }
                            )
                        )
                    )
                ),
                shouldHideNavigationBar: false
            ).apply {
                $0.tabBarItem = UITabBarItem(
                    title: "More",
                    image: UIImage(systemName: "ellipsis.circle"),
                    selectedImage: nil
                )
            }
        case let identity as DetailsNavigationIdentity:
            return BaseViewController(
                screen: DetailsToPresentScreen(
                    viewModel: .init(
                        context: .init(
                            related: .init(
                                value: identity.number
                            ),
                            navigation: .init(
                                followReplaceRootWithNewMain: navigator ?> { replaceRoot(navigator: $0) },
                                followPushOrPopNext: { [weak navigator] value in
                                    navigator?.navigate(
                                        chain: value.map {
                                            NavigationChainLink(
                                                destination: .identity(DetailsNavigationIdentity(number: $0)),
                                                strategy: .popToExisting(),
                                                animated: true,
                                                fallback: NavigationChainLink(
                                                    destination: .identity(DetailsNavigationIdentity(number: $0)),
                                                    strategy: .push(),
                                                    animated: true
                                                )
                                            )
                                        }
                                    )
                                },
                                followRemoveFromStack: { [weak navigator] in
                                    navigator?.navigate(
                                        destination: .identity(DetailsNavigationIdentity(number: -1)),
                                        strategy: .removeFromNavigationStack
                                    )
                                }
                            )
                        )
                    )
                ),
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
            return BaseViewController(
                screen: PrimaryScreen(
                    viewModel: .init(
                        context: .init(
                            navigation: .init(
                                followReplaceRootWithNewMain: navigator ?> { replaceRoot(navigator: $0) },
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
                                }
                            )
                        )
                    )
                ),
                shouldHideNavigationBar: false
            )
        case _ as SecondaryNavigationIdentity:
            return BaseViewController(
                screen: SecondaryScreen(
                    viewModel: .init(
                        context: .init(
                            navigation: .init(
                                followReplaceRootWithNewMain: navigator ?> { replaceRoot(navigator: $0) },
                                followShowSplitSecondary: { [weak navigator] in
                                    navigator?.navigate(
                                        destination: .identity(SecondaryNavigationIdentity()),
                                        strategy: .split(strategy: .secondary(action: .push))
                                    )
                                }
                            )
                        )
                    )
                ),
                shouldHideNavigationBar: false
            )
        case _ as LoginNavigationIdentity:
            return BaseViewController(
                screen: LoginScreen(
                    viewModel: .init(
                        context: .init(
                            source: .init(
                                authorize: authorizationService ?> { $0.authorize() }
                            ),
                            navigation: .init(
                                followReplaceRootWithNewMain: navigator ?> { replaceRoot(navigator: $0) }
                            )
                        )
                    )
                ),
                shouldHideNavigationBar: false
            )
        case _ as SecretInformationIdentity:
            return BaseViewController(
                screen: SecretInformationScreen(
                    viewModel: .init(
                        context: .init(
                            navigation: .init(
                                followReplaceRootWithNewMain: navigator ?> { replaceRoot(navigator: $0) }
                            )
                        )
                    )
                ),
                shouldHideNavigationBar: false
            )
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
