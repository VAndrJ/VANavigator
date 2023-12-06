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
    private(set) var isReplacedEventHandled = false
    private(set) var isMockEventHandled = false

    // MARK: - Responder

    var nextEventResponder: Responder?
    
    func handle(event: ResponderEvent) async -> Bool {
        switch event {
        case _ as ResponderReplacedWindowRootControllerEvent:
            isReplacedEventHandled = true
            
            return true
        case _ as ResponderMockEvent:
            isMockEventHandled = true

            return true
        default:
            return false
        }
    }
}

struct MockRootControllerNavigationIdentity: DefaultNavigationIdentity {}

struct ResponderMockEvent: ResponderEvent {}

func taskDetachedMain(_ f: @escaping @Sendable () -> Sendable) {
    Task.detached {
        await MainActor.run(body: f)
    }
}
