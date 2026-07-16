//
//  PushControllerTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 07.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Testing
import UIKit

@testable import VANavigator

// TODO: - Messages
@Suite(.serialized)
final class PushControllerTests {
    var window: UIWindow? = UIWindow()

    @Test
    func `Pushes controller onto navigation stack`() async {
        await controllerPushOntoNavigationStack(alwaysEmbedded: false)
    }

    @Test
    func `Presents fallback navigation stack when needed`() async {
        await controllerPushOntoNavigationStack(alwaysEmbedded: true)
    }

    @Test
    func `Push fails without fallback`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationStack(navigator: navigator, alwaysEmbedded: false)

        let identity = MockPushControllerNavigationIdentity()
        var result: Bool?
        let expect = expectation(description: "push")
        await push(
            navigator: navigator,
            identity: identity,
            alwaysEmbedded: nil,
            completion: { _, isSuccess in
                result = isSuccess
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((false) == (result))
        #expect(MockRootControllerNavigationIdentity().isEqual(to: window?.rootViewController?.navigationIdentity))
        #expect(MockRootControllerNavigationIdentity().isEqual(to: window?.topController?.navigationIdentity))
    }

    @Test
    func `Repeated push fallbacks eventually report failure`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationStack(navigator: navigator, alwaysEmbedded: false)

        var result: Bool?
        let expect = expectation(description: "push")
        navigator.navigate(
            destination: .identity(MockNavControllerNavigationIdentity(children: [MockRootControllerNavigationIdentity()])),
            strategy: .push(),
            fallback: NavigationChainLink(
                destination: .identity(MockNavControllerNavigationIdentity(children: [MockRootControllerNavigationIdentity()])),
                strategy: .push(),
                animated: true,
                fallback: NavigationChainLink(
                    destination: .identity(MockNavControllerNavigationIdentity(children: [MockRootControllerNavigationIdentity()])),
                    strategy: .push(),
                    animated: true,
                    fallback: NavigationChainLink(
                        destination: .identity(MockNavControllerNavigationIdentity(children: [MockRootControllerNavigationIdentity()])),
                        strategy: .push(),
                        animated: true
                    )
                )
            ),
            completion: { _, isSuccess in
                result = isSuccess
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((false) == (result))
        #expect(MockRootControllerNavigationIdentity().isEqual(to: window?.rootViewController?.navigationIdentity))
        #expect(MockRootControllerNavigationIdentity().isEqual(to: window?.topController?.navigationIdentity))
    }

    @Test
    func `Existing controller instance fails before UIKit push`() async {
        let existingController = UIViewController()
        let navigationController = PushInvocationRecordingNavigationController()
        navigationController.setViewControllers([existingController], animated: false)
        window?.rootViewController = navigationController
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let expect = expectation(description: "push")
        var result: Bool?

        navigator.navigate(
            destination: .controller(existingController),
            strategy: .push(),
            animated: false,
            completion: { _, isSuccess in
                result = isSuccess
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((false) == (result))
        #expect((0) == (navigationController.pushInvocationCount))
        #expect(([existingController]) == (navigationController.viewControllers))
    }

    @Test
    func `Rejected UIKit push reports failure`() async {
        let rootController = UIViewController()
        let pushedController = UIViewController()
        let navigationController = PushInvocationRecordingNavigationController()
        navigationController.setViewControllers([rootController], animated: false)
        navigationController.performsPush = false
        window?.rootViewController = navigationController
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let expect = expectation(description: "push")
        var result: Bool?

        navigator.navigate(
            destination: .controller(pushedController),
            strategy: .push(),
            animated: false,
            completion: { _, isSuccess in
                result = isSuccess
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((false) == (result))
        #expect((1) == (navigationController.pushInvocationCount))
        #expect(([rootController]) == (navigationController.viewControllers))
    }

    @Test
    func `Tab bar controller fails before UIKit push`() async {
        let rootController = UIViewController()
        let tabBarController = UITabBarController()
        let navigationController = PushInvocationRecordingNavigationController()
        navigationController.setViewControllers([rootController], animated: false)
        window?.rootViewController = navigationController
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let expect = expectation(description: "push")
        var result: Bool?

        navigator.navigate(
            destination: .controller(tabBarController),
            strategy: .push(),
            animated: false,
            completion: { _, isSuccess in
                result = isSuccess
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((false) == (result))
        #expect((0) == (navigationController.pushInvocationCount))
        #expect(([rootController]) == (navigationController.viewControllers))
    }

    @Test
    func `Presents controller without navigation embedding`() async {
        await controllerPresentWithNavigation(alwaysEmbedded: false)
    }

    @Test
    func `Presents controller embedded in navigation`() async {
        await controllerPresentWithNavigation(alwaysEmbedded: true)
    }

    func controllerPresentWithNavigation(
        alwaysEmbedded: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationStack(navigator: navigator, alwaysEmbedded: false)

        let identity = MockPushControllerNavigationIdentity()
        let expect = expectation(description: "push")
        await push(
            navigator: navigator,
            identity: identity,
            alwaysEmbedded: alwaysEmbedded,
            completion: { _, _ in expect.fulfill() }
        )

        await fulfillment(of: [expect], timeout: 10)

        // Check that controller was presented
        // and it is the top view controller.
        let expectedIdentity = identity

        #expect(
            (window?.rootViewController as? UINavigationController) == nil,
            sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
        )
        if alwaysEmbedded {
            let navigationController = window?.rootViewController?.presentedViewController as? UINavigationController

            #expect(
                (navigationController) != nil,
                sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
            )
            #expect(
                navigationController?.viewControllers.count == 1,
                sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
            )
            #expect(
                expectedIdentity.isEqual(to: navigationController?.topViewController?.navigationIdentity),
                sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
            )
        } else {
            #expect(
                expectedIdentity.isEqual(to: window?.rootViewController?.presentedViewController?.navigationIdentity),
                "expected not equal to top",
                sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
            )
        }
        #expect(
            expectedIdentity.isEqual(to: window?.topController?.navigationIdentity),
            sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
        )
        #expect(
            (true) == ((window?.topController as? MockViewController)?.isMockEventHandled),
            sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
        )
    }

    func controllerPushOntoNavigationStack(
        alwaysEmbedded: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationStack(navigator: navigator, alwaysEmbedded: true)

        let identity = MockPushControllerNavigationIdentity()
        let expect = expectation(description: "push")
        var responder: UIViewController?
        var result: Bool?
        await push(
            navigator: navigator,
            identity: identity,
            alwaysEmbedded: alwaysEmbedded,
            completion: { controller, isSuccess in
                responder = controller
                result = isSuccess
                expect.fulfill()
            }
        )
        await fulfillment(of: [expect], timeout: 10)

        // Check that controller was pushed
        // and it is the top view controller.
        let rootNavigationController = window?.rootViewController as? UINavigationController
        let expectedIdentity = identity

        #expect((true) == (result))
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
    }

    @Test
    func `Push notifies navigation delegate`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationStack(navigator: navigator, alwaysEmbedded: true)
        let delegate = MockNavigationDelegate()
        (window?.rootViewController as? UINavigationController)?.delegate = delegate
        let identity = MockPushControllerNavigationIdentity()
        let expect = expectation(description: "push")
        var responder: UIViewController?
        var result: Bool?
        await push(
            navigator: navigator,
            identity: identity,
            alwaysEmbedded: false,
            animated: false,
            completion: { controller, isSuccess in
                responder = controller
                result = isSuccess
                expect.fulfill()
            }
        )
        await fulfillment(of: [expect], timeout: 10)

        // Check that controller was pushed
        // and it is the top view controller.
        let rootNavigationController = window?.rootViewController as? UINavigationController
        let expectedIdentity = identity

        #expect((true) == (result))
        #expect(rootNavigationController?.viewControllers.count == 2)
        #expect(expectedIdentity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity))
        #expect(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        #expect(expectedIdentity.isEqual(to: responder?.navigationIdentity))
        #expect((true) == ((responder as? MockViewController)?.isMockEventHandled))
        await waitUntil("navigation delegate didShow callback", timeout: 10) {
            delegate.didShowControllers.count == 1
        }
        #expect(delegate.didShowControllers.count == 1)
        #expect(delegate.didShowControllers.first === responder)
        #expect(delegate.animatedValues == [false])
    }

    @Test
    func `Push dismisses presented controller over navigation stack`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigationStack(navigator: navigator, alwaysEmbedded: true)
        let rootNavigationController = window?.rootViewController as? UINavigationController
        let presentedIdentity = MockPopControllerNavigationIdentity()
        let pushIdentity = MockPushControllerNavigationIdentity()

        let presentExpect = expectation(description: "present")
        navigator.navigate(
            destination: .identity(presentedIdentity),
            strategy: .present(),
            animated: false,
            completion: { _, _ in
                presentExpect.fulfill()
            }
        )

        await fulfillment(of: [presentExpect], timeout: 10)

        #expect((1) == (rootNavigationController?.viewControllers.count))
        #expect(presentedIdentity.isEqual(to: window?.topController?.navigationIdentity))

        let pushExpect = expectation(description: "push")
        var responder: UIViewController?
        var result: Bool?
        navigator.navigate(
            destination: .identity(pushIdentity),
            strategy: .push(),
            animated: false,
            event: ResponderMockEvent(),
            completion: {
                responder = $0
                result = $1
                pushExpect.fulfill()
            }
        )

        await fulfillment(of: [pushExpect], timeout: 10)

        #expect((true) == (result))
        #expect((rootNavigationController?.presentedViewController) == nil)
        #expect((2) == (rootNavigationController?.viewControllers.count))
        #expect(pushIdentity.isEqual(to: rootNavigationController?.topViewController?.navigationIdentity))
        #expect(pushIdentity.isEqual(to: window?.topController?.navigationIdentity))
        #expect(pushIdentity.isEqual(to: responder?.navigationIdentity))
        #expect((true) == ((responder as? MockViewController)?.isMockEventHandled))
    }

    @Test
    func `Push completion preserves animation for visible window that is not key`() async {
        guard
            let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first
        else {
            Issue.record("Missing window scene")

            return
        }

        let keyWindow = UIWindow(windowScene: windowScene)
        keyWindow.rootViewController = UIViewController()
        keyWindow.makeKeyAndVisible()
        defer { keyWindow.isHidden = true }

        let navigationController = AnimationRecordingNavigationController(
            rootViewController: UIViewController()
        )
        let nonKeyWindow = UIWindow(windowScene: windowScene)
        nonKeyWindow.rootViewController = navigationController
        nonKeyWindow.isHidden = false
        window = nonKeyWindow
        navigationController.lastPushAnimated = nil

        #expect((false) == (nonKeyWindow.isKeyWindow))

        let expect = expectation(description: "push completion")
        navigationController.pushViewController(
            UIViewController(),
            animated: true,
            completion: { expect.fulfill() }
        )

        #expect((true) == (navigationController.lastPushAnimated))
        await fulfillment(of: [expect], timeout: 10)
    }

    func push(
        navigator: Navigator,
        identity: any NavigationIdentity,
        alwaysEmbedded: Bool?,
        animated: Bool = true,
        completion: ((UIViewController?, Bool) -> Void)?
    ) async {
        let expect = expectation(description: "push")
        var responder: UIViewController?
        var result = false
        navigator.navigate(
            destination: .identity(identity),
            strategy: .push(),
            animated: animated,
            fallback: alwaysEmbedded.map {
                $0
                    ? NavigationChainLink(
                        destination: .identity(MockNavControllerNavigationIdentity(children: [identity])),
                        strategy: .present(),
                        animated: true
                    )
                    : NavigationChainLink(
                        destination: .identity(identity),
                        strategy: .present(),
                        animated: true
                    )
            },
            event: ResponderMockEvent(),
            completion: {
                responder = $0
                result = $1
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)
        completion?(responder, result)
    }

    func prepareNavigationStack(navigator: Navigator, alwaysEmbedded: Bool) async {
        let identity = MockRootControllerNavigationIdentity()
        let expect = expectation(description: "navigation.replaceWindowRoot")
        navigator.navigate(
            destination: .identity(alwaysEmbedded ? MockNavControllerNavigationIdentity(children: [identity]) : identity),
            strategy: .replaceWindowRoot(),
            completion: { _, _ in expect.fulfill() }
        )

        await fulfillment(of: [expect], timeout: 10)
    }
}

private final class MockNavigationDelegate: NSObject, UINavigationControllerDelegate {
    private(set) var didShowControllers: [UIViewController] = []
    private(set) var animatedValues: [Bool] = []

    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        didShowControllers.append(viewController)
        animatedValues.append(animated)
    }
}

private final class AnimationRecordingNavigationController: UINavigationController {
    var lastPushAnimated: Bool?

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        lastPushAnimated = animated
        super.pushViewController(viewController, animated: animated)
    }
}

private final class PushInvocationRecordingNavigationController: UINavigationController {
    var performsPush = true
    private(set) var pushInvocationCount = 0

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        pushInvocationCount += 1
        if performsPush {
            super.pushViewController(viewController, animated: animated)
        }
    }
}
