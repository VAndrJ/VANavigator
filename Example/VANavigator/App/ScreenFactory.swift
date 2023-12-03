//
//  ScreenFactory.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import VATextureKit

class ScreenFactory: NavigatorScreenFactory {

    func assembleScreen(identity: NavigationIdentity, navigator: Navigator) -> UIViewController {
        switch identity {
        case let identity as TabNavigationIdentity:
            let controller = VATabBarController()
            let tabControllers = identity.tabsIdentity.map { identity in
                let controller = assembleScreen(identity: identity, navigator: navigator)
                controller.navigationIdentity = identity
                return embedInNavigationControllerIfNeeded(controller: controller)
            }
            controller.setViewControllers(tabControllers, animated: false)
            return controller
        case _ as MainNavigationIdentity:
            return ViewController(node: MainControllerNode(viewModel: MainViewModel(data: .init(navigation: .init(
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
                    navigator?.navigate(
                        destination: .identity(DetailsNavigationIdentity(number: -1)),
                        strategy: .pushOrPopToExisting()
                    )
                },
                followTabs: { [weak navigator] in
                    navigator?.navigate(
                        destination: .identity(TabNavigationIdentity(tabsIdentity: [
                            TabDetailNavigationIdentity(),
                            MoreNavigationIdentity(),
                        ])),
                        strategy: .presentOrCloseToExisting
                    )
                }
            )))))
        case _ as TabDetailNavigationIdentity:
            return ViewController(
                node: TabDetailControllerNode(viewModel: TabDetailViewModel(data: .init(navigation: .init(
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
                            (.identity(DetailsNavigationIdentity(number: $0)), .pushOrPopToExisting(), true)
                        })
                    }
                )))),
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
                node: MoreControllerNode(viewModel: MoreViewModel(data: .init(navigation: .init(
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
                            (.identity(DetailsNavigationIdentity(number: $0)), .pushOrPopToExisting(), true)
                        })
                    }
                )))),
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
                node: DetailsToPresentControllerNode(viewModel: DetailsToPresentViewModel(data: .init(
                    related: .init(value: identity.number),
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
                                (.identity(DetailsNavigationIdentity(number: $0)), .pushOrPopToExisting(), true)
                            })
                        }
                    )
                ))),
                shouldHideNavigationBar: false,
                isNotImportant: true
            )
        default:
            assertionFailure("Not implemented \(type(of: identity))")

            return UIViewController()
        }
    }

    func embedInNavigationControllerIfNeeded(controller: UIViewController) -> UIViewController {
        if let controller = controller.orNavigationController {
            return controller
        } else {
            return NavigationController(controller: controller)
        }
    }
}
