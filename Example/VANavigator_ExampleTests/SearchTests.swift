//
//  SearchTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 23.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Testing
import UIKit
import VANavigator

@testable import VANavigator_Example

// TODO: - Messages
@Suite(.serialized)
final class SearchTests {
    let window: UIWindow?

    init() {
        guard let windowScene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            Issue.record("A window scene is required to run view-controller search tests")
            window = nil
            return
        }
        window = UIWindow(windowScene: windowScene)
    }

    @Test
    func `Finds controllers across tab hierarchy`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let primaryIdentity = MockControllerNavigationIdentity()
        let secondaryIdentity = LoginNavigationIdentity()
        let splitIdentity = MockSplitControllerNavigationIdentity(
            primary: primaryIdentity,
            secondary: secondaryIdentity
        )
        let identity = MockRootControllerNavigationIdentity()
        let identity1 = MockPushControllerNavigationIdentity()
        let navIdentity = MockNavControllerNavigationIdentity(children: [identity, identity1])
        let tabIdentity = MockTabControllerNavigationIdentity(children: [navIdentity])
        let presentIdentity = MockPopControllerNavigationIdentity()

        let expect = expectation(description: "navigation.replaceWindowRoot")
        navigator.navigate(
            chain: [
                .init(destination: .identity(splitIdentity), strategy: .replaceWindowRoot(), animated: false),
                .init(destination: .identity(tabIdentity), strategy: .present(), animated: false),
                .init(destination: .identity(presentIdentity), strategy: .present(), animated: false),
            ],
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        await fulfillment(of: [expect], timeout: 10)

        let controller = window?.findController(destination: .identity(identity))
        #expect(identity.isEqual(to: controller?.navigationIdentity))
        #expect((controller) == (window?.findController(destination: .controller(controller!))))
        let controller1 = window?.findController(destination: .identity(identity1))
        #expect(identity1.isEqual(to: controller1?.navigationIdentity))
        #expect((controller1) == (window?.findController(destination: .controller(controller1!))))
        let navController = window?.findController(destination: .identity(navIdentity))
        #expect(navIdentity.isEqual(to: navController?.navigationIdentity))
        #expect((navController) == (window?.findController(destination: .controller(navController!))))
        let tabController = window?.findController(destination: .identity(tabIdentity))
        #expect(tabIdentity.isEqual(to: tabController?.navigationIdentity))
        #expect((tabController) == (window?.findController(destination: .controller(tabController!))))
        let presentedController = window?.findController(destination: .identity(presentIdentity))
        #expect(presentIdentity.isEqual(to: presentedController?.navigationIdentity))
        #expect((presentedController) == (window?.findController(destination: .controller(presentedController!))))
        let splitController = window?.findController(destination: .identity(splitIdentity))
        #expect(splitIdentity.isEqual(to: splitController?.navigationIdentity))
        #expect((splitController) == (window?.findController(destination: .controller(splitController!))))
        let primaryController = window?.findController(destination: .identity(primaryIdentity))
        #expect(primaryIdentity.isEqual(to: primaryController?.navigationIdentity))
        #expect((primaryController) == (window?.findController(destination: .controller(primaryController!))))
        if UIDevice.current.userInterfaceIdiom == .pad {
            let secondaryController = window?.findController(destination: .identity(secondaryIdentity))
            #expect(secondaryIdentity.isEqual(to: secondaryController?.navigationIdentity))
            #expect((secondaryController) == (window?.findController(destination: .controller(secondaryController!))))
        }

        #expect((presentedController) == (window?.topController))
        #expect((tabController) == (controller?.findTabBarController()))
        #expect((tabController) == (controller1?.findTabBarController()))
        #expect((tabController) == (navController?.findTabBarController()))
        #expect((tabController) == (tabController?.findTabBarController()))
        #expect((tabController) == (presentedController?.findTabBarController()))
        #expect((splitController?.findTabBarController()) == nil)
    }

    @Test
    func `Navigation controller search includes presented controller`() async {
        await assertSearchIncludesPresentedController(
            in: UINavigationController(rootViewController: UIViewController())
        )
    }

    @Test
    func `Tab bar controller search includes presented controller`() async {
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [UIViewController()]

        await assertSearchIncludesPresentedController(in: tabBarController)
    }

    @Test
    func `Split view controller search includes presented controller`() async {
        let splitViewController = UISplitViewController(style: .doubleColumn)
        splitViewController.setViewController(UIViewController(), for: .primary)
        splitViewController.setViewController(UIViewController(), for: .secondary)

        await assertSearchIncludesPresentedController(in: splitViewController)
    }

    @Test
    func `Split view top controller uses visible column`() async {
        let splitViewController = UISplitViewController(style: .doubleColumn)
        splitViewController.setViewController(UIViewController(), for: .primary)
        splitViewController.setViewController(UIViewController(), for: .secondary)
        window?.rootViewController = splitViewController
        window?.makeKeyAndVisible()
        splitViewController.view.layoutIfNeeded()

        let visibleController = splitViewController.testColumns
            .compactMap {
                splitViewController.columnNavigationController(for: $0)
                    ?? splitViewController.viewController(for: $0)
            }
            .first { $0.viewIfLoaded?.window != nil }

        #expect((visibleController) != nil)
        #expect((visibleController?.topController) == (splitViewController.topController))
    }

    @Test
    func `Split view search includes generated column navigation stack`() async throws {
        let splitViewController = UISplitViewController(style: .doubleColumn)
        splitViewController.setViewController(UIViewController(), for: .primary)
        splitViewController.setViewController(UIViewController(), for: .secondary)
        window?.rootViewController = splitViewController
        window?.makeKeyAndVisible()
        splitViewController.view.layoutIfNeeded()

        let navigationController = try #require(
            splitViewController.testColumns
                .compactMap { splitViewController.columnNavigationController(for: $0) }
                .first { $0.viewIfLoaded?.window != nil }
        )
        let pushedController = UIViewController()
        let identity = MockPushControllerNavigationIdentity()
        pushedController.navigationIdentity = identity
        navigationController.pushViewController(pushedController, animated: false)

        #expect((pushedController) == (splitViewController.topController))
        #expect((pushedController) == (splitViewController.findController(controller: pushedController, withPresented: false)))
        #expect((pushedController) == (splitViewController.findController(identity: identity, withPresented: false)))
    }

    @Test
    func `Custom container search includes child controller`() async {
        let container = UIViewController()
        let child = UIViewController()
        let identity = MockPushControllerNavigationIdentity()
        child.navigationIdentity = identity
        container.addChild(child)
        container.view.addSubview(child.view)
        child.didMove(toParent: container)
        window?.rootViewController = container
        window?.makeKeyAndVisible()

        #expect((child) === (container.topController))
        #expect((child) === (container.findController(controller: child, withPresented: false)))
        #expect((child) === (container.findController(identity: identity, withPresented: false)))
        #expect((child) === (window?.findController(destination: .identity(identity))))
    }

    private func assertSearchIncludesPresentedController(
        in container: UIViewController,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let identity = MockPopControllerNavigationIdentity()
        let presentedController = UIViewController()
        presentedController.navigationIdentity = identity
        window?.rootViewController = container
        window?.makeKeyAndVisible()

        let expect = expectation(description: "present")
        container.present(presentedController, animated: false) {
            expect.fulfill()
        }

        await fulfillment(of: [expect], timeout: 10)

        #expect(
            (presentedController) == (container.presentedViewController),
            sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
        )
        #expect(
            (presentedController) == (container.topController),
            sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
        )
        #expect(
            (presentedController) == (container.findController(controller: presentedController, withPresented: true)),
            sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
        )
        #expect(
            (container.findController(controller: presentedController, withPresented: false)) == nil,
            sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
        )
        #expect(
            (presentedController) == (container.findController(identity: identity, withPresented: true)),
            sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
        )
        #expect(
            (container.findController(identity: identity, withPresented: false)) == nil,
            sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
        )
        #expect(
            (presentedController) == (window?.findController(destination: .identity(identity))),
            sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
        )
    }
}

extension UISplitViewController {
    fileprivate var testColumns: [Column] {
        var columns: [Column] = [.compact]
        if #available(iOS 26.0, *) {
            columns.append(.inspector)
        }
        columns.append(contentsOf: [.secondary, .supplementary, .primary])

        return columns
    }
}
