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
        case _ as LoginNavigationIdentity:
            return UIViewController()
        case _ as SecretInformationIdentity:
            return ViewController(
                node: SecretInformationControllerNode(viewModel: SecretInformationViewModel(data: .init(
                    navigation: .init(followReplaceRootWithNewMain: {}))
                ))
            )
        case _ as MockRootControllerNavigationIdentity:
            return MockRootViewController()
        case _ as MockPushControllerNavigationIdentity:
            return MockPushViewController()
        case _ as MockPopControllerNavigationIdentity:
            return MockPopViewController()
        case let identity as MockNavControllerNavigationIdentity:
            let controller = MockNavigationController()
            controller.setViewControllers(
                identity.childIdentity.map {
                    let controller = assembleScreen(identity: $0, navigator: navigator)
                    controller.navigationIdentity = $0
                    return controller
                },
                animated: false
            )
            controller.navigationIdentity = identity
            
            return controller
        default:
            return UIViewController()
        }
    }
}

class MockNavigationController: UINavigationController, Responder {

    var nextEventResponder: Responder? {
        get { topController as? Responder }
        set {}
    }

    func handle(event: ResponderEvent) async -> Bool {
        await nextEventResponder?.handle(event: event) ?? false
    }
}

class MockViewController: UIViewController {
    var isMockEventHandled = false
}

class MockPopViewController: MockViewController, Responder {
    private(set) var isPoppedEventHandled = false

    // MARK: - Responder

    var nextEventResponder: Responder?

    func handle(event: ResponderEvent) async -> Bool {
        switch event {
        case _ as ResponderMockEvent:
            isMockEventHandled = true

            return true
        case _ as ResponderPoppedToExistingEvent:
            isPoppedEventHandled = true

            return true
        default:
            return false
        }
    }
}

class MockPushViewController: MockViewController, Responder {

    // MARK: - Responder

    var nextEventResponder: Responder?

    func handle(event: ResponderEvent) async -> Bool {
        switch event {
        case _ as ResponderMockEvent:
            isMockEventHandled = true

            return true
        default:
            return false
        }
    }
}

class MockRootViewController: MockViewController, Responder {
    private(set) var isReplacedEventHandled = false

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

struct MockPushControllerNavigationIdentity: DefaultNavigationIdentity {}

struct MockPopControllerNavigationIdentity: DefaultNavigationIdentity {}

struct MockNavControllerNavigationIdentity: DefaultNavigationIdentity {
    let childIdentity: [NavigationIdentity]
}

struct ResponderMockEvent: ResponderEvent {}

func taskDetachedMain(_ f: @escaping @Sendable () -> Sendable) {
    Task.detached {
        await MainActor.run(body: f)
    }
}
