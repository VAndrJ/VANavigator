//
//  Support.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 06.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import VANavigator
@testable import VANavigator_Example

class MockScreenFactory: NavigatorScreenFactory {

    func assembleScreen(identity: NavigationIdentity, navigator: Navigator) -> UIViewController {
        switch identity {
        case _ as MockRootControllerNavigationIdentity:
            return MockRootViewController()
        default:
            return UIViewController()
        }
    }

    func embedInNavigationControllerIfNeeded(controller: UIViewController) -> UIViewController {
        if controller is UINavigationController {
            return controller
        } else {
            return UINavigationController(rootViewController: controller)
        }
    }
}

class MockRootViewController: UIViewController, Responder {
    var nextEventResponder: Responder?
    
    func handle(event: ResponderEvent) async -> Bool {
        true
    }
}

struct MockRootControllerNavigationIdentity: DefaultNavigationIdentity {}
