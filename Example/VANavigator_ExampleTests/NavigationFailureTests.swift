//
//  NavigationFailureTests.swift
//  VANavigator_ExampleTests
//

import Testing
import UIKit
import VANavigator

final class NavigationFailureTests {
    @Test
    func `Missing window reports typed failure for every supported strategy`() async {
        let navigator = Navigator(window: nil, screenFactory: MockScreenFactory())
        let destinationController = UIViewController()
        let strategies: [NavigationStrategy] = [
            .removeFromNavigationStack,
            .closeIfTop(),
            .replaceWindowRoot(),
            .present(),
            .closeToExisting,
            .push(),
            .popToExisting(),
            .replaceNavigationRoot,
            .popover(configure: { _, _ in }),
            .split(strategy: .primary(action: .replace)),
        ]
        let completions = strategies.indices.map {
            expectation(description: "missing-window completion \($0)")
        }
        var failures: [NavigationFailure] = []
        var results: [Bool] = []
        navigator.navigationFailureHandler = { failures.append($0) }

        for (index, strategy) in strategies.enumerated() {
            navigator.navigate(
                destination: .controller(destinationController),
                strategy: strategy,
                animated: false,
                completion: { _, result in
                    results.append(result)
                    completions[index].fulfill()
                }
            )
        }

        await fulfillment(of: completions, timeout: 10)

        #expect(results == Array(repeating: false, count: strategies.count))
        #expect(failures.count == strategies.count)
        #expect(failures.allSatisfy { $0.reason == .windowUnavailable })
        #expect(
            failures.allSatisfy {
                $0.destination?.isEqual(to: .controller(destinationController)) == true
            }
        )
        #expect(zip(failures, strategies).allSatisfy { $0.strategy == $1 })
    }

    @Test
    func `Rejected strategy reports before successful fallback`() async {
        let window = UIWindow()
        window.rootViewController = UIViewController()
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let destinationController = UIViewController()
        let completion = expectation(description: "fallback completion")
        var events: [String] = []
        var failures: [NavigationFailure] = []
        var isSuccess: Bool?
        navigator.navigationFailureHandler = {
            failures.append($0)
            events.append("failure")
        }

        navigator.navigate(
            destination: .controller(destinationController),
            strategy: .push(),
            animated: false,
            fallbackStrategies: [.replaceWindowRoot()],
            completion: { _, result in
                isSuccess = result
                events.append("completion")
                completion.fulfill()
            }
        )

        await fulfillment(of: [completion], timeout: 10)

        #expect(isSuccess == true)
        #expect(window.rootViewController === destinationController)
        #expect(events == ["failure", "completion"])
        #expect(failures.count == 1)
        #expect(failures.first?.reason == .navigationControllerUnavailable)
        #expect(failures.first?.strategy == .push())
    }

    @Test
    func `Void helper exposes rejected operation through diagnostics`() async {
        let navigator = Navigator(window: UIWindow(), screenFactory: MockScreenFactory())
        let completion = expectation(description: "helper completion")
        var failures: [NavigationFailure] = []
        navigator.navigationFailureHandler = { failures.append($0) }

        navigator.closeNavigationPresented(
            controller: nil,
            animated: false,
            completion: { completion.fulfill() }
        )

        await fulfillment(of: [completion], timeout: 10)

        #expect(failures.count == 1)
        #expect(failures.first?.reason == .sourceViewControllerUnavailable)
        #expect(failures.first?.destination == nil)
        #expect(failures.first?.strategy == nil)
    }

    @Test
    func `Cancelling interception reports the cancelled destination`() async {
        let window = UIWindow()
        let destinationController = UIViewController()
        let reason = AnyHashable("diagnostic cancellation")
        let interceptor = DiagnosticNavigationInterceptor(
            destination: destinationController,
            reason: reason
        )
        let navigator = Navigator(
            window: window,
            screenFactory: MockScreenFactory(),
            navigationInterceptor: interceptor
        )
        let completion = expectation(description: "interception cancellation")
        var failures: [NavigationFailure] = []
        var isSuccess: Bool?
        navigator.navigationFailureHandler = { failures.append($0) }

        navigator.navigate(
            destination: .controller(destinationController),
            strategy: .replaceWindowRoot(),
            animated: false,
            completion: { _, result in
                isSuccess = result
                completion.fulfill()
            }
        )
        interceptor.removeIfAvailable(reason: reason)

        await fulfillment(of: [completion], timeout: 10)

        #expect(isSuccess == false)
        #expect(failures.count == 1)
        #expect(failures.first?.reason == .interceptionCancelled)
        #expect(failures.first?.destination?.isEqual(to: .controller(destinationController)) == true)
        #expect(failures.first?.strategy == .replaceWindowRoot())
    }

    @Test
    func `Successful navigation emits no failure diagnostic`() async {
        let window = UIWindow()
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let destinationController = UIViewController()
        let completion = expectation(description: "successful navigation")
        var failures: [NavigationFailure] = []
        navigator.navigationFailureHandler = { failures.append($0) }

        navigator.navigate(
            destination: .controller(destinationController),
            strategy: .replaceWindowRoot(),
            animated: false,
            completion: { _, _ in completion.fulfill() }
        )

        await fulfillment(of: [completion], timeout: 10)

        #expect(failures.isEmpty)
    }

    @Test
    func `Internal strategy does not emit a duplicate diagnostic`() async {
        let destinationController = UIViewController()
        let navigationController = UINavigationController(rootViewController: destinationController)
        let window = UIWindow()
        window.rootViewController = navigationController
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let completion = expectation(description: "single removal diagnostic")
        var failures: [NavigationFailure] = []
        navigator.navigationFailureHandler = { failures.append($0) }

        navigator.navigate(
            destination: .controller(destinationController),
            strategy: .removeFromNavigationStack,
            animated: false,
            completion: { _, _ in completion.fulfill() }
        )

        await fulfillment(of: [completion], timeout: 10)

        #expect(failures.count == 1)
        #expect(failures.first?.reason == .mutationRejected)
        #expect(failures.first?.strategy == .removeFromNavigationStack)
    }
}

private final class DiagnosticNavigationInterceptor: NavigationInterceptor {
    let destination: UIViewController
    let reason: AnyHashable

    init(destination: UIViewController, reason: AnyHashable) {
        self.destination = destination
        self.reason = reason
    }

    override func intercept(destination: NavigationDestination) -> NavigationInterceptionResult? {
        guard destination.isEqual(to: .controller(self.destination)) else { return nil }

        return NavigationInterceptionResult(chain: [], reason: reason)
    }
}
