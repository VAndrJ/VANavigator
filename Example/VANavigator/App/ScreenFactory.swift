//
//  ScreenFactory.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

class ScreenFactory: NavigatorScreenFactory {

    func assembleScreen(identity: NavigationIdentity, navigator: Navigator) -> UIViewController {
        switch identity {
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
                pushOrPresentDetails: { [weak navigator] in
                    navigator?.navigate(
                        destination: .identity(DetailsNavigationIdentity(number: -1)),
                        strategy: .pushOrPopToExisting()
                    )
                }
            )))))
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
            assertionFailure("Not implemented")

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
