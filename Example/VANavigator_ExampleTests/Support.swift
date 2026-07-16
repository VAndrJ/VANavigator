//
//  Support.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 06.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Testing
import UIKit
import VANavigator

nonisolated final class TestExpectation: @unchecked Sendable {
    let description: String
    private let lock = NSLock()
    private var fulfilled = false

    var isFulfilled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return fulfilled
    }

    init(description: String) {
        self.description = description
    }

    func fulfill() {
        lock.lock()
        fulfilled = true
        lock.unlock()
    }
}

func expectation(description: String) -> TestExpectation {
    TestExpectation(description: description)
}

func fulfillment(of expectations: [TestExpectation], timeout: TimeInterval) async {
    let start = DispatchTime.now().uptimeNanoseconds
    let timeoutNanoseconds = UInt64(timeout * 1_000_000_000)

    while let pendingExpectation = expectations.first(where: { !$0.isFulfilled }) {
        if DispatchTime.now().uptimeNanoseconds - start >= timeoutNanoseconds {
            Issue.record("Timed out waiting for '\(pendingExpectation.description)'")
            return
        }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
}

func waitUntil(
    _ description: String,
    timeout: TimeInterval,
    condition: () -> Bool
) async {
    let start = DispatchTime.now().uptimeNanoseconds
    let timeoutNanoseconds = UInt64(timeout * 1_000_000_000)

    while !condition() {
        if DispatchTime.now().uptimeNanoseconds - start >= timeoutNanoseconds {
            Issue.record("Timed out waiting for '\(description)'")
            return
        }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
}

class MockScreenFactory: NavigatorScreenFactory {
    init() {}

    func assembleScreen(identity: any NavigationIdentity, navigator: Navigator) -> UIViewController {
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
            return MockViewController()
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
}

class MockNavigationController: UINavigationController, Responder {
    var nextEventResponder: (any Responder)? {
        get { topController as? (any Responder) }
        set {}
    }

    func handle(event: any ResponderEvent) async -> Bool {
        await nextEventResponder?.handle(event: event) ?? false
    }
}

class MockViewController: UIViewController {
    var isMockEventHandled = false
}

class MockPopViewController: MockViewController, Responder {
    private(set) var isPoppedEventHandled = false

    // MARK: - Responder

    var nextEventResponder: (any Responder)?

    func handle(event: any ResponderEvent) async -> Bool {
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

    var nextEventResponder: (any Responder)?

    func handle(event: any ResponderEvent) async -> Bool {
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

    var nextEventResponder: (any Responder)?

    func handle(event: any ResponderEvent) async -> Bool {
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

    var nextEventResponder: (any Responder)? {
        get { selectedViewController as? (any Responder) }
        set {}
    }

    func handle(event: any ResponderEvent) async -> Bool {
        await nextEventResponder?.handle(event: event) ?? false
    }
}

struct MockRootControllerNavigationIdentity: DefaultNavigationIdentity {}

struct MockPushControllerNavigationIdentity: DefaultNavigationIdentity {}

struct MockPopControllerNavigationIdentity: DefaultNavigationIdentity {}

struct MockControllerNavigationIdentity: DefaultNavigationIdentity {}

struct MockNavControllerNavigationIdentity: DefaultNavigationIdentity {
    let children: [any NavigationIdentity]
}

struct MockSplitControllerNavigationIdentity: DefaultNavigationIdentity {
    let primary: any NavigationIdentity
    let secondary: any NavigationIdentity
    var supplementary: (any NavigationIdentity)?
}

struct MockTabControllerNavigationIdentity: DefaultNavigationIdentity {
    let children: [any NavigationIdentity]
}

struct ResponderMockEvent: ResponderEvent {}

func taskDetachedMain(_ fn: @escaping @Sendable () -> any Sendable) {
    Task.detached {
        await MainActor.run(body: fn)
    }
}
