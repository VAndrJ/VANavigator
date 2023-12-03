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
        default:
            assertionFailure("Not implemented")

            return UIViewController()
        }
    }

    func embedInNavigationControllerIfNeeded(controller: UIViewController) -> UIViewController {
        if let controller = controller.orNavigationController {
            return controller
        } else {
            return UINavigationController(rootViewController: controller)
        }
    }
}
