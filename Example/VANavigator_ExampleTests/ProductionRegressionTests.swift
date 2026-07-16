//
//  ProductionRegressionTests.swift
//  VANavigator_ExampleTests
//

import Testing
import UIKit
@testable import VANavigator

@Suite(.serialized)
final class ProductionRegressionTests {
    @Test
    func `Chain links are intercepted only once`() async {
        let window = UIWindow()
        let destination = UIViewController()
        let interceptor = SecondCallInterceptor(destination: destination)
        let navigator = Navigator(
            window: window,
            screenFactory: MockScreenFactory(),
            navigationInterceptor: interceptor
        )
        let completed = expectation(description: "chain completion")
        var result: Bool?

        navigator.navigate(
            chain: [
                NavigationChainLink(
                    destination: .controller(destination),
                    strategy: .replaceWindowRoot(),
                    animated: false
                )
            ],
            completion: { _, isSuccess in
                result = isSuccess
                completed.fulfill()
            }
        )

        await fulfillment(of: [completed], timeout: 10)

        #expect(interceptor.callCount == 1)
        #expect(result == true)
        #expect(window.rootViewController === destination)
    }

    @Test
    func `Intercepted fallback resumes the rest of its chain and releases navigation state`() async {
        let window = UIWindow()
        let primary = UIViewController()
        let fallback = UIViewController()
        let trailing = UIViewController()
        let interception = UIViewController()
        let interceptor = FallbackInterceptor(
            destination: fallback,
            interceptionDestination: interception
        )
        let navigator = Navigator(
            window: window,
            screenFactory: MockScreenFactory(),
            navigationInterceptor: interceptor
        )
        let requestedNavigation = expectation(description: "requested navigation")
        var requestedResult: Bool?
        var requestedController: UIViewController?

        navigator.navigate(
            chain: [
                NavigationChainLink(
                    destination: .controller(primary),
                    strategy: .push(),
                    animated: false,
                    fallback: NavigationChainLink(
                        destination: .controller(fallback),
                        strategy: .replaceWindowRoot(),
                        animated: false
                    )
                ),
                NavigationChainLink(
                    destination: .controller(trailing),
                    strategy: .replaceWindowRoot(),
                    animated: false
                ),
            ],
            completion: { controller, isSuccess in
                requestedController = controller
                requestedResult = isSuccess
                requestedNavigation.fulfill()
            }
        )

        await waitUntil("fallback interception", timeout: 10) {
            interceptor.checkIsExists(reason: interceptor.reason)
                && window.rootViewController === interception
        }

        #expect(!requestedNavigation.isFulfilled)

        let resolved = expectation(description: "interception resolution")
        interceptor.resolve { _, isSuccess in
            #expect(isSuccess)
            resolved.fulfill()
        }

        await fulfillment(of: [requestedNavigation, resolved], timeout: 10)

        #expect(requestedResult == true)
        #expect(requestedController === trailing)
        #expect(window.rootViewController === trailing)

        let subsequent = UIViewController()
        let subsequentNavigation = expectation(description: "subsequent navigation")
        navigator.navigate(
            destination: .controller(subsequent),
            strategy: .replaceWindowRoot(),
            animated: false,
            completion: { controller, isSuccess in
                #expect(isSuccess)
                #expect(controller === subsequent)
                subsequentNavigation.fulfill()
            }
        )

        await fulfillment(of: [subsequentNavigation], timeout: 10)
        #expect(window.rootViewController === subsequent)
    }

    @Test
    func `Intercepted fallback without a completion resumes the tail once and preserves queue order`() async {
        let window = RootAssignmentRecordingWindow()
        let primary = UIViewController()
        let fallback = UIViewController()
        let trailing = UIViewController()
        let interception = UIViewController()
        let queued = UIViewController()
        let interceptor = FallbackInterceptor(
            destination: fallback,
            interceptionDestination: interception
        )
        let navigator = Navigator(
            window: window,
            screenFactory: MockScreenFactory(),
            navigationInterceptor: interceptor
        )

        navigator.navigate(
            chain: [
                NavigationChainLink(
                    destination: .controller(primary),
                    strategy: .push(),
                    animated: false,
                    fallback: NavigationChainLink(
                        destination: .controller(fallback),
                        strategy: .replaceWindowRoot(),
                        animated: false
                    )
                ),
                NavigationChainLink(
                    destination: .controller(trailing),
                    strategy: .replaceWindowRoot(),
                    animated: false
                ),
            ]
        )

        let resolutionCompleted = expectation(description: "interception resolution")
        interceptor.resolve { _, isSuccess in
            #expect(isSuccess)
            resolutionCompleted.fulfill()
        }

        let queuedCompleted = expectation(description: "queued navigation")
        navigator.navigate(
            destination: .controller(queued),
            strategy: .replaceWindowRoot(),
            animated: false,
            completion: { _, isSuccess in
                #expect(isSuccess)
                queuedCompleted.fulfill()
            }
        )

        await fulfillment(of: [resolutionCompleted, queuedCompleted], timeout: 10)
        await Task.yield()
        await Task.yield()

        #expect(window.rootViewController === queued)
        #expect(window.rootAssignments.filter { $0 === trailing }.count == 1)
        let trailingIndex = window.rootAssignments.firstIndex { $0 === trailing }
        let queuedIndex = window.rootAssignments.firstIndex { $0 === queued }
        #expect(trailingIndex != nil)
        #expect(queuedIndex != nil)
        #expect(trailingIndex.map { index in queuedIndex.map { index < $0 } ?? false } == true)
    }

    @Test
    func `Removing an interception reason completes its pending navigation once with failure`() {
        let target = UIViewController()
        let reason = AnyHashable("specific reason")
        let interceptor = PendingNavigationInterceptor(entries: [(target, reason)])
        let navigator = Navigator(
            window: UIWindow(),
            screenFactory: MockScreenFactory(),
            navigationInterceptor: interceptor
        )
        var completionCount = 0
        var completionController: UIViewController?
        var completionResult: Bool?

        navigator.navigate(
            destination: .controller(target),
            strategy: .replaceWindowRoot(),
            animated: false,
            completion: { controller, isSuccess in
                completionCount += 1
                completionController = controller
                completionResult = isSuccess
            }
        )

        #expect(interceptor.checkIsExists(reason: reason))
        interceptor.removeIfAvailable(reason: reason)
        interceptor.removeIfAvailable(reason: reason)
        interceptor.interceptionResolved(reason: reason, completion: nil)

        #expect(completionCount == 1)
        #expect(completionController == nil)
        #expect(completionResult == false)
        #expect(!interceptor.checkIsExists(reason: reason))
    }

    @Test
    func `Removing all interception reasons completes every pending navigation once with failure`() {
        let first = UIViewController()
        let second = UIViewController()
        let firstReason = AnyHashable("first reason")
        let secondReason = AnyHashable("second reason")
        let interceptor = PendingNavigationInterceptor(entries: [
            (first, firstReason),
            (second, secondReason),
        ])
        let navigator = Navigator(
            window: UIWindow(),
            screenFactory: MockScreenFactory(),
            navigationInterceptor: interceptor
        )
        var firstCompletionCount = 0
        var secondCompletionCount = 0
        var results: [Bool] = []

        navigator.navigate(
            destination: .controller(first),
            strategy: .replaceWindowRoot(),
            animated: false,
            completion: { _, isSuccess in
                firstCompletionCount += 1
                results.append(isSuccess)
            }
        )
        navigator.navigate(
            destination: .controller(second),
            strategy: .replaceWindowRoot(),
            animated: false,
            completion: { _, isSuccess in
                secondCompletionCount += 1
                results.append(isSuccess)
            }
        )

        interceptor.removeAllReasons()
        interceptor.removeAllReasons()

        #expect(firstCompletionCount == 1)
        #expect(secondCompletionCount == 1)
        #expect(results.count == 2)
        #expect(results.allSatisfy { !$0 })
        #expect(interceptor.getInterceptionReasons().isEmpty)
    }

    @Test
    func `Replacing an interceptor cancels its pending navigation once with failure`() {
        let target = UIViewController()
        let reason = AnyHashable("replacement reason")
        let oldInterceptor = PendingNavigationInterceptor(entries: [(target, reason)])
        let navigator = Navigator(
            window: UIWindow(),
            screenFactory: MockScreenFactory(),
            navigationInterceptor: oldInterceptor
        )
        var completionCount = 0
        var result: Bool?

        navigator.navigate(
            destination: .controller(target),
            strategy: .replaceWindowRoot(),
            animated: false,
            completion: { _, isSuccess in
                completionCount += 1
                result = isSuccess
            }
        )

        #expect(oldInterceptor.checkIsExists(reason: reason))
        navigator.navigationInterceptor = NavigationInterceptor()
        oldInterceptor.removeAllReasons()

        #expect(completionCount == 1)
        #expect(result == false)
        #expect(oldInterceptor.getInterceptionReasons().isEmpty)
    }

    @Test
    func `Removing the only controller from a presented navigation stack never dismisses it`() async {
        let window = UIWindow()
        let presenter = UIViewController()
        let target = UIViewController()
        let presentedNavigationController = UINavigationController(rootViewController: target)
        window.rootViewController = presenter
        window.makeKeyAndVisible()

        let presented = expectation(description: "modal presentation")
        presenter.present(presentedNavigationController, animated: false) {
            presented.fulfill()
        }
        await fulfillment(of: [presented], timeout: 10)

        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let removed = expectation(description: "remove from navigation stack")
        var result: Bool?
        navigator.navigate(
            destination: .controller(target),
            strategy: .removeFromNavigationStack,
            animated: false,
            completion: { _, isSuccess in
                result = isSuccess
                removed.fulfill()
            }
        )

        await fulfillment(of: [removed], timeout: 10)

        #expect(result == false)
        #expect(presenter.presentedViewController === presentedNavigationController)
        #expect(presentedNavigationController.viewControllers == [target])
    }

    @Test
    func `Popover without an anchor uses fallback without asking UIKit to present`() async {
        let window = UIWindow()
        let source = PresentationRecordingViewController()
        let popoverDestination = UIViewController()
        let fallbackDestination = UIViewController()
        window.rootViewController = source
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let completed = expectation(description: "popover fallback")
        var result: Bool?
        var resultController: UIViewController?

        navigator.navigate(
            destination: .controller(popoverDestination),
            strategy: .popover(configure: { _, _ in }),
            animated: false,
            fallback: NavigationChainLink(
                destination: .controller(fallbackDestination),
                strategy: .replaceWindowRoot(),
                animated: false
            ),
            completion: { controller, isSuccess in
                resultController = controller
                result = isSuccess
                completed.fulfill()
            }
        )

        await fulfillment(of: [completed], timeout: 10)

        #expect(source.presentationAttempts == 0)
        #expect(result == true)
        #expect(resultController === fallbackDestination)
        #expect(window.rootViewController === fallbackDestination)
    }

    @Test
    @available(iOS 16.0, *)
    func `Popover accepts a source item anchor`() async {
        let window = UIWindow()
        let source = UIViewController()
        let destination = UIViewController()
        let anchor = UIView()
        source.view.addSubview(anchor)
        window.rootViewController = source
        window.makeKeyAndVisible()
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let completed = expectation(description: "source item popover")
        var result: Bool?

        navigator.navigate(
            destination: .controller(destination),
            strategy: .popover(configure: { popover, _ in
                popover.sourceItem = anchor
            }),
            animated: false,
            completion: { controller, isSuccess in
                result = isSuccess
                #expect(controller === destination)
                completed.fulfill()
            }
        )

        await fulfillment(of: [completed], timeout: 10)

        #expect(result == true)
        #expect(source.presentedViewController === destination)
    }

    @Test
    func `Presentation strategies reject an ancestor containing their source controller`() {
        let window = UIWindow()
        let ancestor = UIViewController()
        let source = PresentationRecordingViewController()
        ancestor.addChild(source)
        ancestor.view.addSubview(source.view)
        source.didMove(toParent: ancestor)
        window.rootViewController = ancestor
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        var presentationResult: Bool?
        var popoverResult: Bool?
        var popoverConfigurationCount = 0

        navigator.navigate(
            destination: .controller(ancestor),
            strategy: .present(),
            animated: false,
            completion: { _, isSuccess in
                presentationResult = isSuccess
            }
        )
        navigator.navigate(
            destination: .controller(ancestor),
            strategy: .popover(configure: { _, _ in
                popoverConfigurationCount += 1
            }),
            animated: false,
            completion: { _, isSuccess in
                popoverResult = isSuccess
            }
        )

        #expect(presentationResult == false)
        #expect(popoverResult == false)
        #expect(popoverConfigurationCount == 0)
        #expect(source.presentationAttempts == 0)
        #expect(source.parent === ancestor)
    }

    @Test
    func `Push rejects a custom ancestor containing the destination navigation controller`() async {
        let hierarchy = makeAncestorNavigationHierarchy()
        let navigator = Navigator(window: hierarchy.window, screenFactory: MockScreenFactory())
        let completed = expectation(description: "rejected ancestor push")
        var result: Bool?

        navigator.navigate(
            destination: .controller(hierarchy.ancestor),
            strategy: .push(),
            animated: false,
            completion: { _, isSuccess in
                result = isSuccess
                completed.fulfill()
            }
        )

        await fulfillment(of: [completed], timeout: 10)

        #expect(result == false)
        #expect(hierarchy.navigationController.pushAttempts == 0)
        #expect(hierarchy.navigationController.topViewController === hierarchy.leaf)
        #expect(hierarchy.navigationController.parent === hierarchy.ancestor)
    }

    @Test
    func `Replacing navigation root rejects a custom ancestor containing the navigation controller`() async {
        let hierarchy = makeAncestorNavigationHierarchy()
        let navigator = Navigator(window: hierarchy.window, screenFactory: MockScreenFactory())
        let completed = expectation(description: "rejected ancestor root replacement")
        var result: Bool?

        navigator.navigate(
            destination: .controller(hierarchy.ancestor),
            strategy: .replaceNavigationRoot,
            animated: false,
            completion: { _, isSuccess in
                result = isSuccess
                completed.fulfill()
            }
        )

        await fulfillment(of: [completed], timeout: 10)

        #expect(result == false)
        #expect(hierarchy.navigationController.setViewControllersAttempts == 0)
        #expect(hierarchy.navigationController.viewControllers == [hierarchy.leaf])
        #expect(hierarchy.navigationController.parent === hierarchy.ancestor)
    }

    @Test
    func `Push rejects a presenter containing the destination navigation controller`() async {
        let hierarchy = await makePresentedAncestorNavigationHierarchy()
        let navigator = Navigator(window: hierarchy.window, screenFactory: MockScreenFactory())
        let completed = expectation(description: "rejected presenter push")
        var result: Bool?

        navigator.navigate(
            destination: .controller(hierarchy.ancestor),
            strategy: .push(),
            animated: false,
            completion: { _, isSuccess in
                result = isSuccess
                completed.fulfill()
            }
        )

        await fulfillment(of: [completed], timeout: 10)

        #expect(result == false)
        #expect(hierarchy.navigationController.pushAttempts == 0)
        #expect(hierarchy.navigationController.viewControllers == [hierarchy.leaf])
        #expect(hierarchy.ancestor.presentedViewController === hierarchy.navigationController)
    }

    @Test
    func `Replacing navigation root rejects a presenter containing the navigation controller`() async {
        let hierarchy = await makePresentedAncestorNavigationHierarchy()
        let navigator = Navigator(window: hierarchy.window, screenFactory: MockScreenFactory())
        let completed = expectation(description: "rejected presenter root replacement")
        var result: Bool?

        navigator.navigate(
            destination: .controller(hierarchy.ancestor),
            strategy: .replaceNavigationRoot,
            animated: false,
            completion: { _, isSuccess in
                result = isSuccess
                completed.fulfill()
            }
        )

        await fulfillment(of: [completed], timeout: 10)

        #expect(result == false)
        #expect(hierarchy.navigationController.setViewControllersAttempts == 0)
        #expect(hierarchy.navigationController.viewControllers == [hierarchy.leaf])
        #expect(hierarchy.ancestor.presentedViewController === hierarchy.navigationController)
    }

    @Test
    func `Removing an absent navigation stack destination uses fallback`() async {
        let window = UIWindow()
        let leaf = UIViewController()
        let navigationController = UINavigationController(rootViewController: leaf)
        let missing = UIViewController()
        let fallbackDestination = UIViewController()
        window.rootViewController = navigationController
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let completed = expectation(description: "missing removal fallback")
        var result: Bool?
        var resultController: UIViewController?

        navigator.navigate(
            destination: .controller(missing),
            strategy: .removeFromNavigationStack,
            animated: false,
            fallback: NavigationChainLink(
                destination: .controller(fallbackDestination),
                strategy: .replaceWindowRoot(),
                animated: false
            ),
            completion: { controller, isSuccess in
                resultController = controller
                result = isSuccess
                completed.fulfill()
            }
        )

        await fulfillment(of: [completed], timeout: 10)

        #expect(result == true)
        #expect(resultController === fallbackDestination)
        #expect(window.rootViewController === fallbackDestination)
        #expect(navigationController.viewControllers == [leaf])
    }

    @Test
    func `Replacing window root rejects a parented candidate and uses fallback`() async {
        let window = UIWindow()
        let currentRoot = UIViewController()
        let candidate = UIViewController()
        let fallbackDestination = UIViewController()
        currentRoot.addChild(candidate)
        currentRoot.view.addSubview(candidate.view)
        candidate.didMove(toParent: currentRoot)
        window.rootViewController = currentRoot
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let completed = expectation(description: "parented root fallback")
        var result: Bool?
        var resultController: UIViewController?

        navigator.navigate(
            destination: .controller(candidate),
            strategy: .replaceWindowRoot(),
            animated: false,
            fallback: NavigationChainLink(
                destination: .controller(fallbackDestination),
                strategy: .replaceWindowRoot(),
                animated: false
            ),
            completion: { controller, isSuccess in
                resultController = controller
                result = isSuccess
                completed.fulfill()
            }
        )

        await fulfillment(of: [completed], timeout: 10)

        #expect(result == true)
        #expect(resultController === fallbackDestination)
        #expect(window.rootViewController === fallbackDestination)
        #expect(candidate.parent === currentRoot)
    }

    @Test
    func `Replacing window root safely promotes a stable presented candidate`() async {
        let window = UIWindow()
        let currentRoot = UIViewController()
        let candidate = UIViewController()
        window.rootViewController = currentRoot
        window.makeKeyAndVisible()
        let presented = expectation(description: "presented root candidate")
        currentRoot.present(candidate, animated: false) {
            presented.fulfill()
        }
        await fulfillment(of: [presented], timeout: 10)
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let completed = expectation(description: "presented root fallback")
        var result: Bool?
        var resultController: UIViewController?

        navigator.navigate(
            destination: .controller(candidate),
            strategy: .replaceWindowRoot(),
            animated: false,
            completion: { controller, isSuccess in
                resultController = controller
                result = isSuccess
                completed.fulfill()
            }
        )

        await fulfillment(of: [completed], timeout: 10)

        #expect(result == true)
        #expect(resultController === candidate)
        #expect(window.rootViewController === candidate)
        #expect(candidate.presentingViewController == nil)
    }

    @Test
    func `Replacing window root verifies the assignment before reporting success`() async {
        let window = RootAssignmentRejectingWindow()
        let currentRoot = UIViewController()
        let rejectedCandidate = UIViewController()
        let fallbackDestination = UIViewController()
        window.rootViewController = currentRoot
        window.rejectedRoot = rejectedCandidate
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let completed = expectation(description: "rejected root assignment fallback")
        var result: Bool?
        var resultController: UIViewController?

        navigator.navigate(
            destination: .controller(rejectedCandidate),
            strategy: .replaceWindowRoot(),
            animated: false,
            fallback: NavigationChainLink(
                destination: .controller(fallbackDestination),
                strategy: .replaceWindowRoot(),
                animated: false
            ),
            completion: { controller, isSuccess in
                resultController = controller
                result = isSuccess
                completed.fulfill()
            }
        )

        await fulfillment(of: [completed], timeout: 10)

        #expect(result == true)
        #expect(resultController === fallbackDestination)
        #expect(window.rootViewController === fallbackDestination)
    }

    @Test
    func `Replacing window root with its current controller remains successful`() async {
        let window = UIWindow()
        let currentRoot = UIViewController()
        window.rootViewController = currentRoot
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let completed = expectation(description: "existing root")
        var result: Bool?
        var resultController: UIViewController?

        navigator.navigate(
            destination: .controller(currentRoot),
            strategy: .replaceWindowRoot(),
            animated: false,
            completion: { controller, isSuccess in
                resultController = controller
                result = isSuccess
                completed.fulfill()
            }
        )

        await fulfillment(of: [completed], timeout: 10)

        #expect(result == true)
        #expect(resultController === currentRoot)
        #expect(window.rootViewController === currentRoot)
    }

    @Test
    func `Replacing window root with its current controller dismisses its modal hierarchy`() async {
        let window = UIWindow()
        let currentRoot = UIViewController()
        let modal = UIViewController()
        window.rootViewController = currentRoot
        window.makeKeyAndVisible()
        let presented = expectation(description: "present current-root modal")
        currentRoot.present(modal, animated: false) {
            presented.fulfill()
        }
        await fulfillment(of: [presented], timeout: 10)
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let completed = expectation(description: "replace existing root")
        var result: Bool?

        navigator.navigate(
            destination: .controller(currentRoot),
            strategy: .replaceWindowRoot(),
            animated: false,
            completion: { _, isSuccess in
                result = isSuccess
                completed.fulfill()
            }
        )

        await fulfillment(of: [completed], timeout: 10)

        #expect(result == true)
        #expect(window.rootViewController === currentRoot)
        #expect(currentRoot.presentedViewController == nil)
        #expect(modal.presentingViewController == nil)
    }

    @Test
    func `Direct window root replacement rejects a parented candidate exactly once`() async {
        let window = UIWindow()
        let currentRoot = UIViewController()
        let candidate = UIViewController()
        currentRoot.addChild(candidate)
        window.rootViewController = currentRoot
        var completionCount = 0

        window.set(rootViewController: candidate) {
            completionCount += 1
        }

        await Task.yield()

        #expect(completionCount == 1)
        #expect(window.rootViewController === currentRoot)
        #expect(candidate.parent === currentRoot)
    }

    @Test
    func `Selecting a nested tab activates every containing tab controller`() {
        let target = UIViewController()
        let innerTabController = UITabBarController()
        innerTabController.viewControllers = [UIViewController(), target]
        innerTabController.selectedIndex = 0

        let innerContainer = UIViewController()
        innerContainer.addChild(innerTabController)
        innerContainer.view.addSubview(innerTabController.view)
        innerTabController.didMove(toParent: innerContainer)

        let outerTabController = UITabBarController()
        outerTabController.viewControllers = [UIViewController(), innerContainer]
        outerTabController.selectedIndex = 0
        let navigator = Navigator(window: nil, screenFactory: MockScreenFactory())
        var completionCount = 0

        navigator.selectTabIfNeeded(controller: target) {
            completionCount += 1
        }

        #expect(completionCount == 1)
        #expect(innerTabController.selectedViewController === target)
        #expect(outerTabController.selectedViewController === innerContainer)
    }

    private func makeAncestorNavigationHierarchy() -> (
        window: UIWindow,
        ancestor: UIViewController,
        navigationController: MutationRecordingNavigationController,
        leaf: UIViewController
    ) {
        let window = UIWindow()
        let ancestor = UIViewController()
        let navigationController = MutationRecordingNavigationController()
        let leaf = UIViewController()
        navigationController.setViewControllers([leaf], animated: false)
        ancestor.addChild(navigationController)
        ancestor.view.addSubview(navigationController.view)
        navigationController.didMove(toParent: ancestor)
        navigationController.beginRecording()
        window.rootViewController = ancestor

        return (window, ancestor, navigationController, leaf)
    }

    private func makePresentedAncestorNavigationHierarchy() async -> (
        window: UIWindow,
        ancestor: UIViewController,
        navigationController: MutationRecordingNavigationController,
        leaf: UIViewController
    ) {
        let window = UIWindow()
        let ancestor = UIViewController()
        let navigationController = MutationRecordingNavigationController()
        let leaf = UIViewController()
        navigationController.setViewControllers([leaf], animated: false)
        window.rootViewController = ancestor
        window.makeKeyAndVisible()
        let presented = expectation(description: "presented navigation hierarchy")
        ancestor.present(navigationController, animated: false) {
            presented.fulfill()
        }
        await fulfillment(of: [presented], timeout: 10)
        navigationController.beginRecording()

        return (window, ancestor, navigationController, leaf)
    }
}

private final class SecondCallInterceptor: NavigationInterceptor {
    let destination: UIViewController
    private(set) var callCount = 0

    init(destination: UIViewController) {
        self.destination = destination
    }

    override func intercept(destination: NavigationDestination) -> NavigationInterceptionResult? {
        guard destination.isEqual(to: .controller(self.destination)) else { return nil }

        callCount += 1
        guard callCount > 1 else { return nil }

        return NavigationInterceptionResult(chain: [], reason: "duplicate interception")
    }
}

private final class FallbackInterceptor: NavigationInterceptor {
    let destination: UIViewController
    let interceptionDestination: UIViewController
    let reason = AnyHashable("fallback interception")
    private var isBlocking = true

    init(destination: UIViewController, interceptionDestination: UIViewController) {
        self.destination = destination
        self.interceptionDestination = interceptionDestination
    }

    override func intercept(destination: NavigationDestination) -> NavigationInterceptionResult? {
        guard isBlocking, destination.isEqual(to: .controller(self.destination)) else { return nil }

        return NavigationInterceptionResult(
            link: NavigationChainLink(
                destination: .controller(interceptionDestination),
                strategy: .replaceWindowRoot(),
                animated: false
            ),
            reason: reason
        )
    }

    func resolve(completion: ((UIViewController?, Bool) -> Void)?) {
        isBlocking = false
        interceptionResolved(reason: reason, completion: completion)
    }
}

private final class PendingNavigationInterceptor: NavigationInterceptor {
    let entries: [(destination: UIViewController, reason: AnyHashable)]

    init(entries: [(UIViewController, AnyHashable)]) {
        self.entries = entries
    }

    override func intercept(destination: NavigationDestination) -> NavigationInterceptionResult? {
        guard case let .controller(controller) = destination,
            let entry = entries.first(where: { $0.destination === controller })
        else {
            return nil
        }

        return NavigationInterceptionResult(chain: [], reason: entry.reason)
    }
}

private final class PresentationRecordingViewController: UIViewController {
    private(set) var presentationAttempts = 0

    override func present(
        _ viewControllerToPresent: UIViewController,
        animated flag: Bool,
        completion: (() -> Void)? = nil
    ) {
        presentationAttempts += 1
        completion?()
    }
}

private final class MutationRecordingNavigationController: UINavigationController {
    private var isRecording = false
    private(set) var pushAttempts = 0
    private(set) var setViewControllersAttempts = 0

    func beginRecording() {
        isRecording = true
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        guard isRecording else {
            super.pushViewController(viewController, animated: animated)

            return
        }

        pushAttempts += 1
    }

    override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
        guard isRecording else {
            super.setViewControllers(viewControllers, animated: animated)

            return
        }

        setViewControllersAttempts += 1
    }
}

private final class RootAssignmentRejectingWindow: UIWindow {
    var rejectedRoot: UIViewController?

    override var rootViewController: UIViewController? {
        get { super.rootViewController }
        set {
            if let rejectedRoot, newValue === rejectedRoot {
                return
            }

            super.rootViewController = newValue
        }
    }
}

private final class RootAssignmentRecordingWindow: UIWindow {
    private(set) var rootAssignments: [UIViewController] = []

    override var rootViewController: UIViewController? {
        get { super.rootViewController }
        set {
            if let newValue {
                rootAssignments.append(newValue)
            }
            super.rootViewController = newValue
        }
    }
}
