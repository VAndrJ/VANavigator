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
//        case _ as QueueNavigationIdentity:
//            return ViewController(
//                node: NavigationQueueExampleControllerNode(viewModel: .init(data: .init(
//                    navigation: .init(
//                        followReplaceRootWithNewMain: { [weak navigator] in
//                            let transition = CATransition()
//                            transition.duration = 0.3
//                            transition.type = .reveal
//                            navigator?.navigate(
//                                destination: .identity(MainNavigationIdentity()),
//                                strategy: .replaceWindowRoot(transition: transition)
//                            )
//                        },
//                        followPresentAndClose: { [weak navigator] in
//                            for _ in 0..<$0 {
//                                navigator?.navigate(
//                                    destination: .identity(MoreNavigationIdentity()),
//                                    strategy: .present()
//                                )
//                                navigator?.navigate(
//                                    destination: .identity(MoreNavigationIdentity()),
//                                    strategy: .closeIfTop()
//                                )
//                            }
//                        }
//                    )
//                )))
//            )
//        case _ as TabPresentExampleNavigationIdentity:
//            return ViewController(
//                node: TabPresentExampleControllerNode(viewModel: .init(data: .init(
//                    navigation: .init(
//                        followPresentFromTop: { [weak navigator] in
//                            navigator?.navigate(
//                                destination: .controller(UIViewController().apply {
//                                    $0.view.backgroundColor = .blue.withAlphaComponent(0.3)
//                                    $0.modalPresentationStyle = .overCurrentContext
//                                }),
//                                strategy: .present(),
//                                completion: { controller, _ in
//                                    if let controller {
//                                        mainAsync(after: 1) {
//                                            navigator?.navigate(
//                                                destination: .controller(controller),
//                                                strategy: .closeIfTop()
//                                            )
//                                        }
//                                    }
//                                }
//                            )
//                        },
//                        followPresentFromTab: { [weak navigator] in
//                            navigator?.navigate(
//                                destination: .controller(UIViewController().apply {
//                                    $0.view.backgroundColor = .green.withAlphaComponent(0.3)
//                                    $0.modalPresentationStyle = .overCurrentContext
//                                }),
//                                strategy: .present(source: .tabBarController),
//                                completion: { controller, _ in
//                                    if let controller {
//                                        mainAsync(after: 1) {
//                                            navigator?.navigate(
//                                                destination: .controller(controller),
//                                                strategy: .closeIfTop()
//                                            )
//                                        }
//                                    }
//                                }
//                            )
//                        },
//                        followPresentPopover: { [weak navigator] source in
//                            navigator?.navigate(
//                                destination: .identity(NavNavigationIdentity(children: [
//                                    DetailsNavigationIdentity(number: 11),
//                                    DetailsNavigationIdentity(number: 12),
//                                ])),
//                                strategy: .popover(configure: { [weak source] popover, _ in
//                                    popover.permittedArrowDirections = .up
//                                    popover.sourceView = source
//                                })
//                            )
//                        }
//                    )
//                ))),
//                shouldHideNavigationBar: false
//            ).apply {
//                $0.tabBarItem = UITabBarItem(
//                    title: "Present",
//                    image: UIImage(systemName: "p.circle"),
//                    selectedImage: nil
//                )
//            }
        case let identity as NavNavigationIdentity:
            return NavigationController(controllers: identity.children.map { identity in
                assembleScreen(identity: identity, navigator: navigator).apply {
                    $0.navigationIdentity = identity
                }
            })
//        case let identity as TabNavigationIdentity:
//            let controller = VATabBarController()
//            let tabControllers = identity.children.map { identity in
//                let controller = assembleScreen(identity: identity, navigator: navigator)
//                controller.navigationIdentity = identity
//
//                return NavigationController(controller: controller)
//            }
//            controller.setViewControllers(tabControllers, animated: false)
//            controller.tabBar.backgroundColor = .yellow
//
//            return controller
        case _ as MainNavigationIdentity:
            return ViewController(view: MainScreenView(viewModel: .init(data: .init(
                source: .init(),
                navigation: .init(
                    followReplaceRootWithNewMain: self ?> { [weak navigator] in $0.replaceRoot(navigator: navigator) },
                    followPushOrPresentDetails: navigator ?> {
                        let identity = DetailsNavigationIdentity(number: -1)
                        $0.navigate(
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
                    }
                )
            )))
//            return ViewController(
//                node: MainControllerNode(viewModel: .init(data: .init(
//                    source: .init(
//                        authorizedObs: authorizationService.isAuthorizedObs
//                    ),
//                    navigation: .init(
//                        followTabs: { [weak navigator] in
//                            navigator?.navigate(
//                                destination: .identity(TabNavigationIdentity(children: [
//                                    TabDetailNavigationIdentity(),
//                                    MoreNavigationIdentity(),
//                                    TabPresentExampleNavigationIdentity(),
//                                ])),
//                                strategy: .closeToExisting,
//                                fallbackStrategies: [.replaceWindowRoot()]
//                            )
//                        },
//                        followSplit: { [weak navigator] in
//                            let destination: NavigationDestination = .identity(SplitNavigationIdentity(
//                                primary: PrimaryNavigationIdentity(),
//                                secondary: MoreNavigationIdentity(),
//                                supplementary: SecondaryNavigationIdentity()
//                            ))
//                            navigator?.navigate(
//                                destination: destination,
//                                strategy: .closeToExisting,
//                                fallback: NavigationChainLink(
//                                    destination: destination,
//                                    strategy: .present(),
//                                    animated: true
//                                )
//                            )
//                        },
//                        followShowInSplitOrPresent: { [weak navigator] in
//                            let destination = DetailsNavigationIdentity(number: -1)
//                            navigator?.navigate(
//                                destination: .identity(destination),
//                                strategy: .split(strategy: .secondary(action: .replace)),
//                                fallback: NavigationChainLink(
//                                    destination: .identity(SplitNavigationIdentity(
//                                        primary: PrimaryNavigationIdentity(),
//                                        secondary: destination
//                                    )),
//                                    strategy: .present(),
//                                    animated: true
//                                )
//                            )
//                        },
//                        followLoginedContent: { [weak navigator] in
//                            navigator?.navigate(
//                                destination: .identity(SecretInformationIdentity()),
//                                strategy: .present()
//                            )
//                        },
//                        followQueue: { [weak navigator] in
//                            navigator?.navigate(
//                                destination: .identity(QueueNavigationIdentity()),
//                                strategy: .present()
//                            )
//                        }
//                    )
//                )))
            )
//        case _ as TabDetailNavigationIdentity:
//            return ViewController(
//                node: TabDetailControllerNode(viewModel: .init(data: .init(
//                    navigation: .init(
//                        followReplaceRootWithNewMain: { [weak navigator] in
//                            let transition = CATransition()
//                            transition.duration = 0.3
//                            transition.type = .reveal
//                            navigator?.navigate(
//                                destination: .identity(MainNavigationIdentity()),
//                                strategy: .replaceWindowRoot(transition: transition)
//                            )
//                        },
//                        followPushOrPopNext: { [weak navigator] value in
//                            navigator?.navigate(chain: value.map {
//                                NavigationChainLink(
//                                    destination: .identity(DetailsNavigationIdentity(number: $0)),
//                                    strategy: .popToExisting(),
//                                    animated: true,
//                                    fallback: NavigationChainLink(
//                                        destination: .identity(DetailsNavigationIdentity(number: $0)),
//                                        strategy: .push,
//                                        animated: true
//                                    )
//                                )
//                            })
//                        }
//                    )
//                ))),
//                shouldHideNavigationBar: false
//            ).apply {
//                $0.tabBarItem = UITabBarItem(
//                    title: "Tab details",
//                    image: UIImage(systemName: "info.circle"),
//                    selectedImage: nil
//                )
//            }
//        case _ as MoreNavigationIdentity:
//            return ViewController(
//                node: MoreControllerNode(viewModel: .init(data: .init(
//                    navigation: .init(
//                        followReplaceRootWithNewMain: { [weak navigator] in
//                            let transition = CATransition()
//                            transition.duration = 0.3
//                            transition.type = .reveal
//                            navigator?.navigate(
//                                destination: .identity(MainNavigationIdentity()),
//                                strategy: .replaceWindowRoot(transition: transition)
//                            )
//                        }
//                    )
//                ))),
//                shouldHideNavigationBar: false
//            ).apply {
//                $0.tabBarItem = UITabBarItem(
//                    title: "More",
//                    image: UIImage(systemName: "ellipsis.circle"),
//                    selectedImage: nil
//                )
//            }
        case let identity as DetailsNavigationIdentity:
            return ViewController(view: DetailsScreenView(viewModel: .init(data: .init(
                related: .init(number: identity.number),
                source: .init(),
                navigation: .init(
                    followReplaceRootWithNewMain: self ?> { [weak navigator] in $0.replaceRoot(navigator: navigator) },
                    followPopOrClose: navigator ?> {
                        $0.navigate(
                            destination: .identity(identity),
                            strategy: .closeIfTop(),
                            fallback: .init(
                                destination: .identity(MainNavigationIdentity()),
                                strategy: .closeToExisting,
                                animated: true
                            )
                        )
                    }
                )
            ))))
            //        case let identity as SplitNavigationIdentity:
//            let controller: UISplitViewController
//            if identity.supplementary == nil {
//                controller = UISplitViewController(style: .doubleColumn)
//            } else {
//                controller = UISplitViewController(style: .tripleColumn)
//            }
//            controller.preferredDisplayMode = .automatic
//            controller.preferredSplitBehavior = .tile
//            let primary = identity.primary
//            let primaryController = assembleScreen(identity: primary, navigator: navigator)
//            primaryController.navigationIdentity = primary
//            controller.setViewController(primaryController, for: .primary)
//            let secondary = identity.secondary
//            let secondaryController = assembleScreen(identity: secondary, navigator: navigator)
//            secondaryController.navigationIdentity = secondary
//            controller.setViewController(secondaryController, for: .secondary)
//            if let supplementary = identity.supplementary {
//                let supplementaryController = assembleScreen(identity: supplementary, navigator: navigator)
//                supplementaryController.navigationIdentity = supplementary
//                controller.setViewController(supplementaryController, for: .supplementary)
//            }
//            controller.preferredPrimaryColumnWidthFraction = 0.33
//
//            return controller
//        case _ as PrimaryNavigationIdentity:
//            return ViewController(
//                node: PrimaryControllerNode(viewModel: .init(data: .init(
//                    navigation: .init(
//                        followReplaceRootWithNewMain: { [weak navigator] in
//                            let transition = CATransition()
//                            transition.duration = 0.3
//                            transition.type = .reveal
//                            navigator?.navigate(
//                                destination: .identity(MainNavigationIdentity()),
//                                strategy: .replaceWindowRoot(transition: transition)
//                            )
//                        },
//                        followReplacePrimary: { [weak navigator] in
//                            navigator?.navigate(
//                                destination: .identity(PrimaryNavigationIdentity()),
//                                strategy: .split(strategy: .primary(action: .replace)),
//                                animated: false
//                            )
//                        },
//                        followShowSplitSecondary: { [weak navigator] in
//                            navigator?.navigate(
//                                destination: .identity(SecondaryNavigationIdentity()),
//                                strategy: .split(strategy: .secondary(action: .push))
//                            )
//                        },
//                        followShowInSplitOrPresent: { [weak navigator] in
//                            let destination = DetailsNavigationIdentity(number: -1)
//                            navigator?.navigate(
//                                destination: .identity(destination),
//                                strategy: .split(strategy: .secondary(action: .replace)),
//                                fallback: NavigationChainLink(
//                                    destination: .identity(SplitNavigationIdentity(
//                                        primary: PrimaryNavigationIdentity(),
//                                        secondary: destination
//                                    )),
//                                    strategy: .present(),
//                                    animated: true
//                                )
//                            )
//                        }
//                    )
//                ))),
//                shouldHideNavigationBar: false
//            )
//        case _ as SecondaryNavigationIdentity:
//            return ViewController(
//                node: SecondaryControllerNode(viewModel: .init(data: .init(
//                    navigation: .init(
//                        followReplaceRootWithNewMain: { [weak navigator] in
//                            let transition = CATransition()
//                            transition.duration = 0.3
//                            transition.type = .reveal
//                            navigator?.navigate(
//                                destination: .identity(MainNavigationIdentity()),
//                                strategy: .replaceWindowRoot(transition: transition)
//                            )
//                        },
//                        followShowSplitSecondary: { [weak navigator] in
//                            navigator?.navigate(
//                                destination: .identity(SecondaryNavigationIdentity()),
//                                strategy: .split(strategy: .secondary(action: .push))
//                            )
//                        },
//                        followShowInSplitOrPresent: { [weak navigator] in
//                            let identity = DetailsNavigationIdentity(number: -1)
//                            navigator?.navigate(
//                                destination: .identity(identity),
//                                strategy: .split(strategy: .secondary(action: .replace)),
//                                fallback: NavigationChainLink(
//                                    destination: .identity(SplitNavigationIdentity(
//                                        primary: PrimaryNavigationIdentity(),
//                                        secondary: identity
//                                    )),
//                                    strategy: .present(),
//                                    animated: true
//                                )
//                            )
//                        }
//                    )
//                ))),
//                shouldHideNavigationBar: false
//            )
//        case _ as LoginNavigationIdentity:
//            return ViewController(
//                node: LoginControllerNode(viewModel: .init(data: .init(
//                    source: .init(authorize: { [weak authorizationService] in
//                        authorizationService?.authorize()
//                    }),
//                    navigation: .init(followReplaceRootWithNewMain: { [weak navigator] in
//                        let transition = CATransition()
//                        transition.duration = 0.3
//                        transition.type = .reveal
//                        navigator?.navigate(
//                            destination: .identity(MainNavigationIdentity()),
//                            strategy: .replaceWindowRoot(transition: transition)
//                        )
//                    })
//                ))),
//                shouldHideNavigationBar: false
//            )
//        case _ as SecretInformationIdentity:
//            return ViewController(
//                node: SecretInformationControllerNode(viewModel: .init(data: .init(
//                    navigation: .init(
//                        followReplaceRootWithNewMain: { [weak navigator] in
//                            let transition = CATransition()
//                            transition.duration = 0.3
//                            transition.type = .reveal
//                            navigator?.navigate(
//                                destination: .identity(MainNavigationIdentity()),
//                                strategy: .replaceWindowRoot(transition: transition)
//                            )
//                        }
//                    )
//                ))),
//                shouldHideNavigationBar: false
//            )
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
