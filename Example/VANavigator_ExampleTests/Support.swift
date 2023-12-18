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

    // swiftlint:disable function_body_length
    func assembleScreen(identity: NavigationIdentity, navigator: Navigator) -> UIViewController {
        switch identity {
        case let identity as MockSplitControllerNavigationIdentity:
            let splitController = MockSplitViewController(style: identity.supplementary == nil ? .doubleColumn : .tripleColumn)
            let primary = assembleScreen(identity: identity.primary, navigator: navigator)
            primary.navigationIdentity = identity.primary
            let secondary = assembleScreen(identity: identity.secondary, navigator: navigator)
            secondary.navigationIdentity = identity.secondary
            let supplementary = identity.supplementary.map {
                let controller = assembleScreen(identity: $0, navigator: navigator)
                controller.navigationIdentity = $0
                return controller
            }
            splitController.setViewController(primary, for: .primary)
            splitController.setViewController(secondary, for: .secondary)
            if let supplementary {
                splitController.setViewController(supplementary, for: .supplementary)
            }
            splitController.navigationIdentity = identity

            return splitController
        case let identity as MockTabControllerNavigationIdentity:
            let controller = MockTabBarViewController()
            controller.setViewControllers(
                identity.children.map {
                    let controller = assembleScreen(identity: $0, navigator: navigator)
                    controller.navigationIdentity = $0

                    return controller
                },
                animated: false
            )
            controller.navigationIdentity = identity

            return controller
        case _ as MockControllerNavigationIdentity:
            return UIViewController()
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
                identity.children.map {
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
    // swiftlint:enable function_body_length
}

class MockNavigationController: UINavigationController, Responder {

    var nextEventResponder: Responder? {
        get { topController as? Responder }
        set {} // swiftlint:disable:this unused_setter_value
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

class MockSplitViewController: UISplitViewController {}

class MockTabBarViewController: UITabBarController, Responder {

    // MARK: - Responder

    var nextEventResponder: Responder? {
        get { selectedViewController as? Responder }
        set {} // swiftlint:disable:this unused_setter_value
    }

    func handle(event: ResponderEvent) async -> Bool {
        await nextEventResponder?.handle(event: event) ?? false
    }
}

struct MockRootControllerNavigationIdentity: DefaultNavigationIdentity {}

struct MockPushControllerNavigationIdentity: DefaultNavigationIdentity {}

struct MockPopControllerNavigationIdentity: DefaultNavigationIdentity {}

struct MockControllerNavigationIdentity: DefaultNavigationIdentity {}

struct MockNavControllerNavigationIdentity: DefaultNavigationIdentity {
    let children: [NavigationIdentity]
}

struct MockSplitControllerNavigationIdentity: DefaultNavigationIdentity {
    let primary: NavigationIdentity
    let secondary: NavigationIdentity
    var supplementary: NavigationIdentity?
}

struct MockTabControllerNavigationIdentity: DefaultNavigationIdentity {
    let children: [NavigationIdentity]
}

struct ResponderMockEvent: ResponderEvent {}

func taskDetachedMain(_ fn: @escaping @Sendable () -> Sendable) {
    Task.detached {
        await MainActor.run(body: fn)
    }
}
