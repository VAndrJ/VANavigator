//
//  SearchTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 23.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit
import VANavigator
import XCTest

@testable import VANavigator_Example

// TODO: - Messages
@MainActor
class SearchTests: XCTestCase {
    var window: UIWindow?

    override func setUp() async throws {
        try await super.setUp()

        guard let windowScene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            XCTFail("A window scene is required to run view-controller search tests")
            return
        }
        window = UIWindow(windowScene: windowScene)
    }

    override func tearDown() async throws {
        window?.isHidden = true
        window = nil

        try await super.tearDown()
    }

    func test_tabSearch() {
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

        wait(for: [expect], timeout: 10)

        let controller = window?.findController(destination: .identity(identity))
        XCTAssertTrue(identity.isEqual(to: controller?.navigationIdentity))
        XCTAssertEqual(controller, window?.findController(destination: .controller(controller!)))
        let controller1 = window?.findController(destination: .identity(identity1))
        XCTAssertTrue(identity1.isEqual(to: controller1?.navigationIdentity))
        XCTAssertEqual(controller1, window?.findController(destination: .controller(controller1!)))
        let navController = window?.findController(destination: .identity(navIdentity))
        XCTAssertTrue(navIdentity.isEqual(to: navController?.navigationIdentity))
        XCTAssertEqual(navController, window?.findController(destination: .controller(navController!)))
        let tabController = window?.findController(destination: .identity(tabIdentity))
        XCTAssertTrue(tabIdentity.isEqual(to: tabController?.navigationIdentity))
        XCTAssertEqual(tabController, window?.findController(destination: .controller(tabController!)))
        let presentedController = window?.findController(destination: .identity(presentIdentity))
        XCTAssertTrue(presentIdentity.isEqual(to: presentedController?.navigationIdentity))
        XCTAssertEqual(presentedController, window?.findController(destination: .controller(presentedController!)))
        let splitController = window?.findController(destination: .identity(splitIdentity))
        XCTAssertTrue(splitIdentity.isEqual(to: splitController?.navigationIdentity))
        XCTAssertEqual(splitController, window?.findController(destination: .controller(splitController!)))
        let primaryController = window?.findController(destination: .identity(primaryIdentity))
        XCTAssertTrue(primaryIdentity.isEqual(to: primaryController?.navigationIdentity))
        XCTAssertEqual(primaryController, window?.findController(destination: .controller(primaryController!)))
        if UIDevice.current.userInterfaceIdiom == .pad {
            let secondaryController = window?.findController(destination: .identity(secondaryIdentity))
            XCTAssertTrue(secondaryIdentity.isEqual(to: secondaryController?.navigationIdentity))
            XCTAssertEqual(secondaryController, window?.findController(destination: .controller(secondaryController!)))
        }

        XCTAssertEqual(presentedController, window?.topController)
        XCTAssertEqual(tabController, controller?.findTabBarController())
        XCTAssertEqual(tabController, controller1?.findTabBarController())
        XCTAssertEqual(tabController, navController?.findTabBarController())
        XCTAssertEqual(tabController, tabController?.findTabBarController())
        XCTAssertEqual(tabController, presentedController?.findTabBarController())
        XCTAssertNil(splitController?.findTabBarController())
    }

    func test_navigationControllerSearch_includesPresentedController() {
        assertSearchIncludesPresentedController(
            in: UINavigationController(rootViewController: UIViewController())
        )
    }

    func test_tabBarControllerSearch_includesPresentedController() {
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [UIViewController()]

        assertSearchIncludesPresentedController(in: tabBarController)
    }

    func test_splitViewControllerSearch_includesPresentedController() {
        let splitViewController = UISplitViewController(style: .doubleColumn)
        splitViewController.setViewController(UIViewController(), for: .primary)
        splitViewController.setViewController(UIViewController(), for: .secondary)

        assertSearchIncludesPresentedController(in: splitViewController)
    }

    func test_splitViewControllerTopController_usesVisibleColumn() {
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

        XCTAssertNotNil(visibleController)
        XCTAssertEqual(visibleController?.topController, splitViewController.topController)
    }

    func test_splitViewControllerTopController_andSearch_includeGeneratedColumnNavigationStack() throws {
        let splitViewController = UISplitViewController(style: .doubleColumn)
        splitViewController.setViewController(UIViewController(), for: .primary)
        splitViewController.setViewController(UIViewController(), for: .secondary)
        window?.rootViewController = splitViewController
        window?.makeKeyAndVisible()
        splitViewController.view.layoutIfNeeded()

        let navigationController = try XCTUnwrap(
            splitViewController.testColumns
                .compactMap { splitViewController.columnNavigationController(for: $0) }
                .first { $0.viewIfLoaded?.window != nil }
        )
        let pushedController = UIViewController()
        let identity = MockPushControllerNavigationIdentity()
        pushedController.navigationIdentity = identity
        navigationController.pushViewController(pushedController, animated: false)

        XCTAssertEqual(pushedController, splitViewController.topController)
        XCTAssertEqual(
            pushedController,
            splitViewController.findController(controller: pushedController, withPresented: false)
        )
        XCTAssertEqual(
            pushedController,
            splitViewController.findController(identity: identity, withPresented: false)
        )
    }

    private func assertSearchIncludesPresentedController(
        in container: UIViewController,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let identity = MockPopControllerNavigationIdentity()
        let presentedController = UIViewController()
        presentedController.navigationIdentity = identity
        window?.rootViewController = container
        window?.makeKeyAndVisible()

        let expect = expectation(description: "present")
        container.present(presentedController, animated: false) {
            expect.fulfill()
        }

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(presentedController, container.presentedViewController, file: file, line: line)
        XCTAssertEqual(presentedController, container.topController, file: file, line: line)
        XCTAssertEqual(
            presentedController,
            container.findController(controller: presentedController, withPresented: true),
            file: file,
            line: line
        )
        XCTAssertNil(
            container.findController(controller: presentedController, withPresented: false),
            file: file,
            line: line
        )
        XCTAssertEqual(
            presentedController,
            container.findController(identity: identity, withPresented: true),
            file: file,
            line: line
        )
        XCTAssertNil(
            container.findController(identity: identity, withPresented: false),
            file: file,
            line: line
        )
        XCTAssertEqual(
            presentedController,
            window?.findController(destination: .identity(identity)),
            file: file,
            line: line
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
