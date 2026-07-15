//
//  PushOrPopControllerTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 07.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Testing
import UIKit
import VANavigator

// TODO: - Messages
@Suite(.serialized)
final class PushOrPopControllerTests {
    var window: UIWindow? = UIWindow()

    @Test
    func `Pops to existing controller`() async {
        await controllerPopInNavigationStack(isTop: false)
    }

    @Test
    func `Does not pop when controller is already on top`() async {
        await controllerPopInNavigationStack(isTop: true)
    }

    @Test
    func `Pushes when controller is not in stack`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationStack(navigator: navigator, alwaysEmbedded: true)
        let identity = MockPopControllerNavigationIdentity()

        let rootNavigationController = window?.rootViewController as? UINavigationController

        #expect(rootNavigationController?.viewControllers.count == 1)
        #expect(!(identity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity)))

        let expect = expectation(description: "pushOrPop")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .popToExisting(includingTabs: false),
            fallback: NavigationChainLink(
                destination: .identity(identity),
                strategy: .push(),
                animated: true
            ),
            event: ResponderMockEvent(),
            completion: {
                responder = $0
                result = $1
                taskDetachedMain { expect.fulfill() }
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        // Check that controller was pushed
        // and it is the top view controller.
        let expectedIdentity = identity

        #expect((true) == (result))
        #expect(rootNavigationController?.viewControllers.count == 2)
        #expect(expectedIdentity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity))
        #expect(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        #expect(expectedIdentity.isEqual(to: responder?.navigationIdentity))
        #expect((true) == ((responder as? MockViewController)?.isMockEventHandled))
        #expect((false) == ((responder as? MockPopViewController)?.isPoppedEventHandled))
    }

    @Test
    func `Navigation container does not pop to itself`() async {
        let identity = MockNavControllerNavigationIdentity(children: [])
        let childController = UIViewController()
        let navigationController = PopInvocationRecordingNavigationController()
        navigationController.setViewControllers([childController], animated: false)
        navigationController.navigationIdentity = identity
        window?.rootViewController = navigationController
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let expect = expectation(description: "pop")
        var responder: UIViewController?
        var result: Bool?

        navigator.navigate(
            destination: .identity(identity),
            strategy: .popToExisting(includingTabs: false),
            animated: false,
            completion: { controller, isSuccess in
                responder = controller
                result = isSuccess
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((true) == (result))
        #expect((navigationController) === (responder))
        #expect((0) == (navigationController.popInvocationCount))
        #expect(([childController]) == (navigationController.viewControllers))
    }

    @Test
    func `Rejected UIKit pop reports failure`() async {
        let targetController = UIViewController()
        let topController = UIViewController()
        let navigationController = PopRejectingNavigationController()
        navigationController.setViewControllers([targetController, topController], animated: false)
        window?.rootViewController = navigationController
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let expect = expectation(description: "pop rejected")
        var result: Bool?

        navigator.navigate(
            destination: .controller(targetController),
            strategy: .popToExisting(includingTabs: false),
            animated: false,
            completion: { _, isSuccess in
                result = isSuccess
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((false) == (result))
        #expect(([targetController, topController]) == (navigationController.viewControllers))
        #expect((topController) === (navigationController.topViewController))
    }

    @Test
    func `Finds navigation stack behind presented controller`() async {
        guard let windowScene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            Issue.record("A window scene is required to test presentation traversal")

            return
        }

        window = UIWindow(windowScene: windowScene)
        let targetController = UIViewController()
        let topController = UIViewController()
        let navigationController = UINavigationController()
        navigationController.setViewControllers([targetController, topController], animated: false)
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
        let presentedController = UIViewController()
        let presentedExpectation = expectation(description: "presented")
        navigationController.present(presentedController, animated: false) {
            presentedExpectation.fulfill()
        }
        await fulfillment(of: [presentedExpectation], timeout: 10)
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let expect = expectation(description: "pop behind presentation")
        var responder: UIViewController?
        var result: Bool?

        navigator.navigate(
            destination: .controller(targetController),
            strategy: .popToExisting(includingTabs: false),
            animated: false,
            completion: {
                responder = $0
                result = $1
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((true) == (result))
        #expect((targetController) === (responder))
        #expect((targetController) === (navigationController.topViewController))
        #expect((navigationController.presentedViewController) == nil)
        #expect((presentedController.presentingViewController) == nil)
    }

    @Test
    func `Close if top fails for single controller`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationStack(navigator: navigator, alwaysEmbedded: true)
        let identity = MockRootControllerNavigationIdentity()

        let rootNavigationController = window?.rootViewController as? UINavigationController

        #expect(rootNavigationController?.viewControllers.count == 1)
        #expect(identity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity))

        let expect = expectation(description: "pushOrPop")
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .closeIfTop(),
            event: ResponderMockEvent(),
            completion: { _, isSuccess in
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        // Check that controller was not popped
        // and it is the top view controller.
        let expectedIdentity = identity

        #expect((false) == (result))
        #expect(rootNavigationController?.viewControllers.count == 1)
        #expect(expectedIdentity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity))
        #expect(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    @Test
    func `Close if top uses fallback for single controller`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationStack(navigator: navigator, alwaysEmbedded: true)
        let identity = MockRootControllerNavigationIdentity()

        let rootNavigationController = window?.rootViewController as? UINavigationController

        #expect(rootNavigationController?.viewControllers.count == 1)
        #expect(identity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity))

        let expect = expectation(description: "pushOrPop")
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .closeIfTop(),
            fallback: .init(
                destination: .identity(identity),
                strategy: .push(),
                animated: false
            ),
            event: ResponderMockEvent(),
            completion: { _, isSuccess in
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        let expectedIdentity = identity

        #expect((true) == (result))
        #expect(rootNavigationController?.viewControllers.count == 2)
        #expect(expectedIdentity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity))
        #expect(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    @Test
    func `Pop to existing selects containing tab`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareTabNavigationStack(navigator: navigator, isTop: false)
        let identity = MockPopControllerNavigationIdentity()
        let rootTabController = window?.rootViewController as? UITabBarController

        #expect(rootTabController?.viewControllers?.count == 3)
        #expect(rootTabController?.selectedIndex == 2)
        #expect(!(identity.isEqual(to: window?.topController?.navigationIdentity)))

        let expect = expectation(description: "popSelecting")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .popToExisting(includingTabs: true),
            event: ResponderMockEvent(),
            completion: {
                responder = $0
                result = $1
                taskDetachedMain { expect.fulfill() }
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        let expectedIdentity = identity

        #expect((true) == (result))
        #expect(rootTabController?.selectedIndex == 0)
        #expect(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        #expect(expectedIdentity.isEqual(to: responder?.navigationIdentity))
        #expect((true) == ((responder as? MockViewController)?.isMockEventHandled))
        #expect((true) == ((responder as? MockPopViewController)?.isPoppedEventHandled))
    }

    @Test
    func `Pop to existing stays on selected tab`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareTabNavigationStack(navigator: navigator, isTop: false)
        let identity = MockPopControllerNavigationIdentity()
        let rootTabController = window?.rootViewController as? UITabBarController
        rootTabController?.selectedIndex = 0

        #expect(rootTabController?.viewControllers?.count == 3)
        #expect(rootTabController?.selectedIndex == 0)
        #expect(!(identity.isEqual(to: window?.topController?.navigationIdentity)))

        let expect = expectation(description: "popSelecting")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .popToExisting(includingTabs: true),
            event: ResponderMockEvent(),
            completion: {
                responder = $0
                result = $1
                taskDetachedMain { expect.fulfill() }
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        let expectedIdentity = identity

        #expect((true) == (result))
        #expect(rootTabController?.selectedIndex == 0)
        #expect(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        #expect(expectedIdentity.isEqual(to: responder?.navigationIdentity))
        #expect((true) == ((responder as? MockViewController)?.isMockEventHandled))
        #expect((true) == ((responder as? MockPopViewController)?.isPoppedEventHandled))
    }

    @Test
    func `Missing controller leaves selected tab unchanged`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareTabNavigationStack(navigator: navigator, isTop: true)
        let identity = MockPushControllerNavigationIdentity()
        let rootTabController = window?.rootViewController as? UITabBarController

        #expect(rootTabController?.viewControllers?.count == 3)
        #expect(rootTabController?.selectedIndex == 2)
        #expect(!(identity.isEqual(to: window?.topController?.navigationIdentity)))

        let expect = expectation(description: "popSelecting")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .popToExisting(includingTabs: true),
            event: ResponderMockEvent(),
            completion: {
                responder = $0
                result = $1
                taskDetachedMain { expect.fulfill() }
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((responder) == nil)
        #expect((false) == (result))
        #expect(rootTabController?.selectedIndex == 2)
        #expect(rootTabController?.viewControllers?.count == 3)
        #expect(rootTabController?.selectedIndex == 2)
        #expect(!(identity.isEqual(to: window?.topController?.navigationIdentity)))
    }

    func controllerPopInNavigationStack(
        isTop: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationStack(navigator: navigator, isTop: isTop)
        let identity = MockPopControllerNavigationIdentity()

        let rootNavigationController = window?.rootViewController as? UINavigationController

        #expect(
            rootNavigationController?.viewControllers.count == (isTop ? 2 : 3),
            sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
        )
        if isTop {
            #expect(
                identity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity),
                sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
            )
        } else {
            #expect(
                !(identity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity)),
                sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
            )
        }

        var responder: UIViewController?
        let expect = expectation(description: "push")
        await pushOrPop(
            navigator: navigator,
            identity: identity,
            completion: { controller, _ in
                responder = controller
                expect.fulfill()
            }
        )
        await fulfillment(of: [expect], timeout: 10)
        // Check that controller was popped
        // and it is the top view controller.
        let expectedIdentity = identity

        #expect(
            rootNavigationController?.viewControllers.count == 2,
            sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
        )
        #expect(
            expectedIdentity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity),
            sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
        )
        #expect(
            expectedIdentity.isEqual(to: window?.topController?.navigationIdentity),
            sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
        )
        #expect(
            expectedIdentity.isEqual(to: responder?.navigationIdentity),
            sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
        )
        #expect(
            (true) == ((responder as? MockViewController)?.isMockEventHandled),
            sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
        )
        if !isTop {
            #expect(
                (true) == ((responder as? MockPopViewController)?.isPoppedEventHandled),
                sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
            )
        }
    }

    func pushOrPop(
        navigator: Navigator,
        identity: any NavigationIdentity,
        completion: ((UIViewController?, Bool) -> Void)?
    ) async {
        let expect = expectation(description: "pushOrPop")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(identity),
            strategy: .popToExisting(includingTabs: false),
            event: ResponderMockEvent(),
            completion: {
                responder = $0
                result = $1
                taskDetachedMain { expect.fulfill() }
            }
        )

        await fulfillment(of: [expect], timeout: 10)
        completion?(responder, result ?? false)
    }

    func prepareTabNavigationStack(navigator: Navigator, isTop: Bool) async {
        let identity: MockNavControllerNavigationIdentity
        if isTop {
            identity = MockNavControllerNavigationIdentity(children: [
                MockRootControllerNavigationIdentity(),
                MockPopControllerNavigationIdentity(),
            ])
        } else {
            identity = MockNavControllerNavigationIdentity(children: [
                MockRootControllerNavigationIdentity(),
                MockPopControllerNavigationIdentity(),
                MockPushControllerNavigationIdentity(),
            ])
        }
        let expect = expectation(description: "navigation.replaceWindowRoot")
        navigator.navigate(
            destination: .identity(
                MockTabControllerNavigationIdentity(children: [
                    identity,
                    MockNavControllerNavigationIdentity(children: []),
                    MockNavControllerNavigationIdentity(children: []),
                ])
            ),
            strategy: .replaceWindowRoot(),
            completion: { controller, _ in
                (controller as? UITabBarController)?.selectedIndex = 2
                taskDetachedMain { expect.fulfill() }
            }
        )

        await fulfillment(of: [expect], timeout: 10)
    }

    func prepareNavigationStack(navigator: Navigator, isTop: Bool) async {
        let identity: MockNavControllerNavigationIdentity
        if isTop {
            identity = MockNavControllerNavigationIdentity(children: [
                MockRootControllerNavigationIdentity(),
                MockPopControllerNavigationIdentity(),
            ])
        } else {
            identity = MockNavControllerNavigationIdentity(children: [
                MockRootControllerNavigationIdentity(),
                MockPopControllerNavigationIdentity(),
                MockPushControllerNavigationIdentity(),
            ])
        }
        let expect = expectation(description: "navigation.replaceWindowRoot")
        navigator.navigate(
            destination: .identity(identity),
            strategy: .replaceWindowRoot(),
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        await fulfillment(of: [expect], timeout: 10)
    }

    func prepareNavigationStack(navigator: Navigator, alwaysEmbedded: Bool) async {
        let identity = MockRootControllerNavigationIdentity()
        let expect = expectation(description: "navigation.replaceWindowRoot")
        navigator.navigate(
            destination: .identity(alwaysEmbedded ? MockNavControllerNavigationIdentity(children: [identity]) : identity),
            strategy: .replaceWindowRoot(),
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        await fulfillment(of: [expect], timeout: 10)
    }
}

private final class PopInvocationRecordingNavigationController: UINavigationController {
    private(set) var popInvocationCount = 0

    override func popToViewController(
        _ viewController: UIViewController,
        animated: Bool
    ) -> [UIViewController]? {
        popInvocationCount += 1

        return super.popToViewController(viewController, animated: animated)
    }
}

private final class PopRejectingNavigationController: UINavigationController {
    override func popToViewController(
        _ viewController: UIViewController,
        animated: Bool
    ) -> [UIViewController]? {
        return nil
    }
}
