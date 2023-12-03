//
//  ScreenFactory.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit
import VANavigator

class ScreenFactory: NavigatorScreenFactory {

    func assembleScreen(identity: NavigationIdentity, navigator: Navigator) -> UIViewController {
        switch identity {
        case _ as MainNavigationIdentity:
            return ViewController(node: MainControllerNode(viewModel: MainViewModel(data: .init(navigation: .init(followReplaceRootWithNewMain: { [weak navigator] in
                let transition = CATransition()
                transition.duration = 0.3
                transition.type = kCATransitionFade
                navigator?.navigate(
                    destination: .identity(MainNavigationIdentity()),
                    strategy: .replaceWindowRoot(transition: transition)
                )
            })))))
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
