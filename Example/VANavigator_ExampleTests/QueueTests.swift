//
//  QueueTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 23.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Testing
import UIKit
import VANavigator

// TODO: - Messages
@Suite(.serialized)
final class QueueTests {
    let window: UIWindow? = UIWindow()

    @Test
    func `Navigation requests without delay run in FIFO order`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigation(navigator: navigator)
        let expectedIdentity = MockRootControllerNavigationIdentity()
        let identity = MockPopControllerNavigationIdentity()

        #expect(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        #expect(expectedIdentity.isEqual(to: window?.rootViewController?.navigationIdentity))

        let expect1 = expectation(description: "navigation.present1")
        let expect2 = expectation(description: "navigation.dismiss1")
        let expect3 = expectation(description: "navigation.present2")
        let expect4 = expectation(description: "navigation.dismiss2")
        let expect5 = expectation(description: "navigation.present3")
        let expect6 = expectation(description: "navigation.dismiss3")
        let expect7 = expectation(description: "navigation.present4")
        let expect8 = expectation(description: "navigation.dismiss4")
        var completionOrder: [Int] = []
        var completionResults: [Bool] = []
        navigator.navigate(
            destination: .identity(identity),
            strategy: .present(),
            completion: { _, isSuccess in
                completionOrder.append(1)
                completionResults.append(isSuccess)
                expect1.fulfill()
            }
        )
        navigator.navigate(
            destination: .identity(identity),
            strategy: .closeIfTop(),
            completion: { _, isSuccess in
                completionOrder.append(2)
                completionResults.append(isSuccess)
                expect2.fulfill()
            }
        )
        navigator.navigate(
            destination: .identity(identity),
            strategy: .present(),
            completion: { _, isSuccess in
                completionOrder.append(3)
                completionResults.append(isSuccess)
                expect3.fulfill()
            }
        )
        navigator.navigate(
            destination: .identity(identity),
            strategy: .closeIfTop(),
            completion: { _, isSuccess in
                completionOrder.append(4)
                completionResults.append(isSuccess)
                expect4.fulfill()
            }
        )
        navigator.navigate(
            destination: .identity(identity),
            strategy: .present(),
            completion: { _, isSuccess in
                completionOrder.append(5)
                completionResults.append(isSuccess)
                expect5.fulfill()
            }
        )
        navigator.navigate(
            destination: .identity(identity),
            strategy: .closeIfTop(),
            completion: { _, isSuccess in
                completionOrder.append(6)
                completionResults.append(isSuccess)
                expect6.fulfill()
            }
        )
        navigator.navigate(
            destination: .identity(identity),
            strategy: .present(),
            completion: { _, isSuccess in
                completionOrder.append(7)
                completionResults.append(isSuccess)
                expect7.fulfill()
            }
        )
        navigator.navigate(
            destination: .identity(identity),
            strategy: .closeIfTop(),
            completion: { _, isSuccess in
                completionOrder.append(8)
                completionResults.append(isSuccess)
                expect8.fulfill()
            }
        )

        await fulfillment(of: [expect1, expect2, expect3, expect4, expect5, expect6, expect7, expect8], timeout: 10)

        #expect(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        #expect(expectedIdentity.isEqual(to: window?.rootViewController?.navigationIdentity))
        #expect(completionOrder == Array(1...8))
        #expect(completionResults == Array(repeating: true, count: 8))
    }

    @Test
    func `Navigation chains without delay run in FIFO order`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigation(navigator: navigator)
        let expectedIdentity = MockRootControllerNavigationIdentity()
        let identity = MockPopControllerNavigationIdentity()

        #expect(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        #expect(expectedIdentity.isEqual(to: window?.rootViewController?.navigationIdentity))

        let expect1 = expectation(description: "navigation.present1")
        let expect2 = expectation(description: "navigation.dismiss1")
        let expect3 = expectation(description: "navigation.present2")
        let expect4 = expectation(description: "navigation.dismiss2")
        let expect5 = expectation(description: "navigation.present3")
        let expect6 = expectation(description: "navigation.dismiss3")
        let expect7 = expectation(description: "navigation.present4")
        let expect8 = expectation(description: "navigation.dismiss4")
        var completionOrder: [Int] = []
        var completionResults: [Bool] = []
        navigator.navigate(
            chain: [.init(destination: .identity(identity), strategy: .present(), animated: true)],
            completion: { _, isSuccess in
                completionOrder.append(1)
                completionResults.append(isSuccess)
                expect1.fulfill()
            }
        )
        navigator.navigate(
            chain: [.init(destination: .identity(identity), strategy: .closeIfTop(), animated: true)],
            completion: { _, isSuccess in
                completionOrder.append(2)
                completionResults.append(isSuccess)
                expect2.fulfill()
            }
        )
        navigator.navigate(
            chain: [.init(destination: .identity(identity), strategy: .present(), animated: true)],
            completion: { _, isSuccess in
                completionOrder.append(3)
                completionResults.append(isSuccess)
                expect3.fulfill()
            }
        )
        navigator.navigate(
            chain: [.init(destination: .identity(identity), strategy: .closeIfTop(), animated: true)],
            completion: { _, isSuccess in
                completionOrder.append(4)
                completionResults.append(isSuccess)
                expect4.fulfill()
            }
        )
        navigator.navigate(
            chain: [.init(destination: .identity(identity), strategy: .present(), animated: true)],
            completion: { _, isSuccess in
                completionOrder.append(5)
                completionResults.append(isSuccess)
                expect5.fulfill()
            }
        )
        navigator.navigate(
            chain: [.init(destination: .identity(identity), strategy: .closeIfTop(), animated: true)],
            completion: { _, isSuccess in
                completionOrder.append(6)
                completionResults.append(isSuccess)
                expect6.fulfill()
            }
        )
        navigator.navigate(
            chain: [],
            completion: { _, isSuccess in
                completionOrder.append(7)
                completionResults.append(isSuccess)
                expect7.fulfill()
            }
        )
        navigator.navigate(
            chain: [],
            completion: { _, isSuccess in
                completionOrder.append(8)
                completionResults.append(isSuccess)
                expect8.fulfill()
            }
        )

        await fulfillment(of: [expect1, expect2, expect3, expect4, expect5, expect6, expect7, expect8], timeout: 10)

        #expect(expectedIdentity.isEqual(to: window?.topController?.navigationIdentity))
        #expect(expectedIdentity.isEqual(to: window?.rootViewController?.navigationIdentity))
        #expect(completionOrder == Array(1...8))
        #expect(completionResults == [true, true, true, true, true, true, false, false])
    }

    @Test
    func `Completion runs before queued navigation starts`() async {
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        await prepareNavigation(navigator: navigator)
        let presentedIdentity = MockPopControllerNavigationIdentity()
        let presentExpect = expectation(description: "navigation.present")
        let closeExpect = expectation(description: "navigation.close")
        var wasPresentedAtCompletion = false

        navigator.navigate(
            destination: .identity(presentedIdentity),
            strategy: .present(),
            animated: false,
            completion: { [weak self] _, _ in
                wasPresentedAtCompletion = presentedIdentity.isEqual(to: self?.window?.topController?.navigationIdentity)
                presentExpect.fulfill()
            }
        )
        navigator.navigate(
            destination: .identity(presentedIdentity),
            strategy: .closeIfTop(),
            animated: false,
            completion: { _, _ in
                closeExpect.fulfill()
            }
        )

        await fulfillment(of: [presentExpect, closeExpect], timeout: 10)

        #expect(wasPresentedAtCompletion)
        #expect(MockRootControllerNavigationIdentity().isEqual(to: window?.topController?.navigationIdentity))
    }

    @Test
    func `Navigation chain stops after failed link`() async {
        let initialController = UIViewController()
        let skippedController = UIViewController()
        window?.rootViewController = initialController
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let expect = expectation(description: "navigation.chain")
        var result: Bool?

        navigator.navigate(
            chain: [
                NavigationChainLink(
                    destination: .identity(MockControllerNavigationIdentity()),
                    strategy: .popToExisting(includingTabs: false),
                    animated: false
                ),
                NavigationChainLink(
                    destination: .controller(skippedController),
                    strategy: .replaceWindowRoot(),
                    animated: false
                ),
            ],
            completion: { _, isSuccess in
                result = isSuccess
                expect.fulfill()
            }
        )

        await fulfillment(of: [expect], timeout: 10)

        #expect((false) == (result))
        #expect((initialController) === (window?.rootViewController))
        #expect((skippedController) !== (window?.rootViewController))
    }

    func prepareNavigation(navigator: Navigator) async {
        let expect = expectation(description: "navigation.replaceWindowRoot")
        navigator.navigate(
            destination: .identity(MockRootControllerNavigationIdentity()),
            strategy: .replaceWindowRoot(),
            completion: { _, _ in expect.fulfill() }
        )

        await fulfillment(of: [expect], timeout: 10)
    }
}
