//
//  CloseIfTopControllerTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 07.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import XCTest
import VANavigator
import VATextureKit

// TODO: - Messages
class CloseIfTopControllerTests: XCTestCase, MainActorIsolated {
    var window: UIWindow?

    override func setUp() {
        window = UIWindow()
    }

    override func tearDown() {
        window = nil
    }

    func test_controllerDismiss() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        preparePresented(navigator: navigator)
        let topIdentity = MockPushControllerNavigationIdentity()

        XCTAssertTrue(topIdentity.isEqual(to: window?.topController?.navigationIdentity))

        let expect = expectation(description: "navigation.closeIfTop")
        var result: Bool?
        navigator.navigate(
            destination: .identity(topIdentity),
            strategy: .closeIfTop(),
            completion: { _, isSuccess in
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        let expectedIdentity = MockPopControllerNavigationIdentity()

        XCTAssertEqual(true, result)
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    func test_controllerPop_notDismissed() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        preparePresented(navigator: navigator)
        let topIdentity = MockPushControllerNavigationIdentity()

        XCTAssertTrue(topIdentity.isEqual(to: window?.topController?.navigationIdentity))

        let expect = expectation(description: "navigation.closeIfTop")
        var result: Bool?
        navigator.navigate(
            destination: .identity(topIdentity),
            strategy: .closeIfTop(tryToDismiss: false),
            completion: { _, isSuccess in
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        let expectedIdentity = topIdentity

        XCTAssertEqual(false, result)
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
    }

    func test_controllerClose_withoutWindow() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let topIdentity = MockPushControllerNavigationIdentity()

        XCTAssertNil(window?.topController)

        let expect = expectation(description: "navigation.closeIfTop")
        var result: Bool?
        navigator.navigate(
            destination: .identity(topIdentity),
            strategy: .closeIfTop(tryToDismiss: false),
            completion: { _, isSuccess in
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        XCTAssertEqual(false, result)
    }

    func test_controllerPop() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStack(navigator: navigator)
        let topIdentity = MockPushControllerNavigationIdentity()
        let navigationController = window?.rootViewController as? UINavigationController

        XCTAssertTrue(topIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertEqual(3, navigationController?.viewControllers.count)

        let expect = expectation(description: "navigation.closeIfTop")
        var result: Bool?
        navigator.navigate(
            destination: .identity(topIdentity),
            strategy: .closeIfTop(),
            event: ResponderMockEvent(),
            completion: { _, isSuccess in
                result = isSuccess
                taskDetachedMain { expect.fulfill() }
            }
        )

        wait(for: [expect], timeout: 10)

        let expectedIdentity = MockPopControllerNavigationIdentity()

        XCTAssertEqual(true, result)
        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertEqual(2, navigationController?.viewControllers.count)
        XCTAssertTrue(expectedIdentity.isEqual(to: navigationController?.topViewController?.navigationIdentity))
    }

    func test_controllerPop_notPopped() {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        prepareNavigationStack(navigator: navigator)
        let topIdentity = MockPushControllerNavigationIdentity()
        let navigationController = window?.rootViewController as? UINavigationController

        XCTAssertTrue(topIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertEqual(3, navigationController?.viewControllers.count)

        let expect = expectation(description: "navigation.closeIfTop")
        navigator.navigate(
            destination: .identity(topIdentity),
            strategy: .closeIfTop(tryToPop: false),
            event: ResponderMockEvent(),
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)

        let expectedIdentity = topIdentity

        XCTAssertTrue(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        XCTAssertEqual(3, navigationController?.viewControllers.count)
        XCTAssertTrue(expectedIdentity.isEqual(to: navigationController?.topViewController?.navigationIdentity))
    }

    func prepareNavigationStack(navigator: Navigator) {
        let expect = expectation(description: "navigation.prepareNavigationStack")
        navigator.navigate(
            chain: [
                NavigationChainLink(
                    destination: .identity(MockNavControllerNavigationIdentity(children: [
                        MockRootControllerNavigationIdentity(),
                    ])),
                    strategy: .replaceWindowRoot(),
                    animated: false
                ),
                NavigationChainLink(
                    destination: .identity(MockPopControllerNavigationIdentity()),
                    strategy: .push(),
                    animated: false
                ),
                NavigationChainLink(
                    destination: .identity(MockPushControllerNavigationIdentity()),
                    strategy: .push(),
                    animated: false
                ),
            ],
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)
    }

    func preparePresented(navigator: Navigator) {
        let expect = expectation(description: "navigation.prepareNavigationStack")
        navigator.navigate(
            chain: [
                NavigationChainLink(
                    destination: .identity(MockRootControllerNavigationIdentity()),
                    strategy: .replaceWindowRoot(),
                    animated: false
                ),
                NavigationChainLink(
                    destination: .identity(MockPopControllerNavigationIdentity()),
                    strategy: .present(),
                    animated: false
                ),
                NavigationChainLink(
                    destination: .identity(MockPushControllerNavigationIdentity()),
                    strategy: .present(),
                    animated: false
                ),
            ],
            completion: { _, _ in taskDetachedMain { expect.fulfill() } }
        )

        wait(for: [expect], timeout: 10)
    }
}
