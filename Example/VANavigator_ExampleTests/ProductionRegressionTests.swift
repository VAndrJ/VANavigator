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

    @Test
    func `Cancelling an old interception does not release a newer active navigation`() async {
        let window = UIWindow()
        let interceptedController = UIViewController()
        let reason = AnyHashable("stale intercepted operation")
        let interceptor = PendingNavigationInterceptor(entries: [(interceptedController, reason)])
        let navigator = Navigator(
            window: window,
            screenFactory: MockScreenFactory(),
            navigationInterceptor: interceptor
        )
        let activeController = SuspendedResponderViewController()
        let queuedController = UIViewController()
        let interceptedCompletion = expectation(description: "intercepted cancellation")
        let activeCompletion = expectation(description: "active navigation")
        let queuedCompletion = expectation(description: "queued navigation")
        var completionOrder: [String] = []

        navigator.navigate(
            destination: .controller(interceptedController),
            strategy: .replaceWindowRoot(),
            animated: false,
            completion: { _, isSuccess in
                #expect(!isSuccess)
                completionOrder.append("intercepted")
                interceptedCompletion.fulfill()
            }
        )
        navigator.navigate(
            destination: .controller(activeController),
            strategy: .replaceWindowRoot(),
            animated: false,
            event: SuspendedResponderEvent(),
            completion: { _, isSuccess in
                #expect(isSuccess)
                completionOrder.append("active")
                activeCompletion.fulfill()
            }
        )
        navigator.navigate(
            destination: .controller(queuedController),
            strategy: .replaceWindowRoot(),
            animated: false,
            completion: { _, isSuccess in
                #expect(isSuccess)
                completionOrder.append("queued")
                queuedCompletion.fulfill()
            }
        )

        await waitUntil("active responder suspension", timeout: 10) {
            activeController.isSuspended
        }
        interceptor.removeIfAvailable(reason: reason)

        #expect(interceptedCompletion.isFulfilled)
        #expect(!activeCompletion.isFulfilled)
        #expect(!queuedCompletion.isFulfilled)
        #expect(window.rootViewController === activeController)

        activeController.resume()
        await fulfillment(of: [activeCompletion, queuedCompletion], timeout: 10)

        #expect(completionOrder == ["intercepted", "active", "queued"])
        #expect(window.rootViewController === queuedController)
    }

    @Test
    func `Active navigation retains the navigator until its queued work completes`() async {
        let window = UIWindow()
        let activeController = SuspendedResponderViewController()
        let queuedController = UIViewController()
        var navigator: Navigator? = Navigator(window: window, screenFactory: MockScreenFactory())
        let retainedNavigator = WeakReference(navigator)
        let activeCompletion = expectation(description: "retained active navigation")
        let queuedCompletion = expectation(description: "retained queued navigation")

        navigator?.navigate(
            destination: .controller(activeController),
            strategy: .replaceWindowRoot(),
            animated: false,
            event: SuspendedResponderEvent(),
            completion: { _, isSuccess in
                #expect(isSuccess)
                activeCompletion.fulfill()
            }
        )
        navigator?.navigate(
            destination: .controller(queuedController),
            strategy: .replaceWindowRoot(),
            animated: false,
            completion: { _, isSuccess in
                #expect(isSuccess)
                queuedCompletion.fulfill()
            }
        )

        await waitUntil("retained responder suspension", timeout: 10) {
            activeController.isSuspended
        }
        navigator = nil

        #expect(retainedNavigator.value != nil)
        #expect(!queuedCompletion.isFulfilled)

        activeController.resume()
        await fulfillment(of: [activeCompletion, queuedCompletion], timeout: 10)
        await waitUntil("navigator release", timeout: 10) {
            retainedNavigator.value == nil
        }

        #expect(window.rootViewController === queuedController)
    }

    @Test
    func `Queued animated stack mutations wait for prior transition cleanup`() async {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let windowScene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            Issue.record("Missing window scene")

            return
        }

        let window = UIWindow(windowScene: windowScene)
        let rootController = UIViewController()
        let navigationController = UINavigationController(rootViewController: rootController)
        let transitionDelegate = HoldingNavigationTransitionDelegate()
        navigationController.delegate = transitionDelegate
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        _ = navigationController.view
        window.layoutIfNeeded()
        defer {
            transitionDelegate.finishTransition()
            window.isHidden = true
        }

        await waitUntil("visible queued-transition hierarchy", timeout: 10) {
            navigationController.viewIfLoaded?.window === window
        }
        try? await Task.sleep(nanoseconds: 50_000_000)

        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let firstController = UIViewController()
        let secondController = UIViewController()
        let firstCompletion = expectation(description: "first animated push")
        let secondCompletion = expectation(description: "queued animated push")
        var results: [Bool] = []

        navigator.navigate(
            destination: .controller(firstController),
            strategy: .push(),
            animated: true,
            completion: { _, isSuccess in
                results.append(isSuccess)
                firstCompletion.fulfill()
            }
        )
        navigator.navigate(
            destination: .controller(secondController),
            strategy: .push(),
            animated: true,
            completion: { _, isSuccess in
                results.append(isSuccess)
                secondCompletion.fulfill()
            }
        )

        await waitUntil("first navigator transition", timeout: 10) {
            transitionDelegate.hasActiveTransition
                && navigationController.topViewController === firstController
        }
        #expect(!firstCompletion.isFulfilled)
        #expect(!secondCompletion.isFulfilled)

        transitionDelegate.finishTransition()
        await fulfillment(of: [firstCompletion], timeout: 10)
        await waitUntil("queued navigator transition", timeout: 10) {
            transitionDelegate.hasActiveTransition
                && navigationController.topViewController === secondController
        }

        #expect(!secondCompletion.isFulfilled)
        transitionDelegate.finishTransition()
        await fulfillment(of: [secondCompletion], timeout: 10)

        #expect(results == [true, true])
        #expect(navigationController.viewControllers == [rootController, firstController, secondController])
    }

    @Test
    func `Transition completion fires once when coordinator rejects animation registration`() async {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let windowScene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            Issue.record("Missing window scene")

            return
        }

        let window = UIWindow(windowScene: windowScene)
        let rootController = UIViewController()
        let navigationController = FalseReturningCoordinatorNavigationController()
        navigationController.setViewControllers([rootController], animated: false)
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        _ = navigationController.view
        window.layoutIfNeeded()
        defer { window.isHidden = true }

        await waitUntil("visible false-return coordinator hierarchy", timeout: 10) {
            navigationController.viewIfLoaded?.window === window
        }
        try? await Task.sleep(nanoseconds: 50_000_000)

        let completed = expectation(description: "once-only transition completion")
        var completionCount = 0
        navigationController.pushViewController(
            UIViewController(),
            animated: true,
            completion: {
                completionCount += 1
                if completionCount == 1 {
                    completed.fulfill()
                }
            }
        )

        await fulfillment(of: [completed], timeout: 10)
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }

        #expect(completionCount == 1)
        #expect(navigationController.viewControllers.count == 2)
    }

    @Test
    func `Animated dismissal retains navigator until queued work completes`() async {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let windowScene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            Issue.record("Missing window scene")

            return
        }

        let window = UIWindow(windowScene: windowScene)
        let rootController = UIViewController()
        let dismissedController = UIViewController()
        let transitionDelegate = HoldingDismissalTransitionDelegate()
        dismissedController.modalPresentationStyle = .custom
        dismissedController.transitioningDelegate = transitionDelegate
        window.rootViewController = rootController
        window.makeKeyAndVisible()
        defer {
            transitionDelegate.finishTransition()
            window.isHidden = true
        }

        let presentation = expectation(description: "dismissal retention setup")
        rootController.present(dismissedController, animated: false) {
            presentation.fulfill()
        }
        await fulfillment(of: [presentation], timeout: 10)

        let queuedController = UIViewController()
        var navigator: Navigator? = Navigator(window: window, screenFactory: MockScreenFactory())
        let retainedNavigator = WeakReference(navigator)
        let dismissalCompletion = expectation(description: "retained animated dismissal")
        let queuedCompletion = expectation(description: "work queued behind animated dismissal")

        navigator?.navigate(
            destination: .controller(dismissedController),
            strategy: .closeIfTop(tryToPop: false),
            animated: true,
            completion: { _, isSuccess in
                #expect(isSuccess)
                dismissalCompletion.fulfill()
            }
        )
        navigator?.navigate(
            destination: .controller(queuedController),
            strategy: .replaceWindowRoot(),
            animated: false,
            completion: { _, isSuccess in
                #expect(isSuccess)
                queuedCompletion.fulfill()
            }
        )

        await waitUntil("held dismissal transition", timeout: 10) {
            transitionDelegate.hasActiveTransition
        }
        navigator = nil

        #expect(retainedNavigator.value != nil)
        #expect(!dismissalCompletion.isFulfilled)
        #expect(!queuedCompletion.isFulfilled)

        transitionDelegate.finishTransition()
        await fulfillment(of: [dismissalCompletion, queuedCompletion], timeout: 10)
        await waitUntil("navigator release after dismissal", timeout: 10) {
            retainedNavigator.value == nil
        }

        #expect(window.rootViewController === queuedController)
    }

    @Test
    func `Navigation mutations fail safely during an external transition`() async {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let windowScene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            Issue.record("Missing window scene")

            return
        }

        let window = UIWindow(windowScene: windowScene)
        let rootController = UIViewController()
        let navigationController = MutationRecordingNavigationController(rootViewController: rootController)
        let transitionDelegate = HoldingNavigationTransitionDelegate()
        navigationController.delegate = transitionDelegate
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        _ = navigationController.view
        window.layoutIfNeeded()
        defer {
            transitionDelegate.finishTransition()
            window.isHidden = true
        }

        await waitUntil("visible navigation hierarchy", timeout: 10) {
            navigationController.viewIfLoaded?.window === window
        }
        try? await Task.sleep(nanoseconds: 50_000_000)

        let transitionController = UIViewController()
        navigationController.pushViewController(transitionController, animated: true)
        await waitUntil("external navigation transition", timeout: 10) {
            transitionDelegate.hasActiveTransition
                && (
                    navigationController.transitionCoordinator != nil
                        || rootController.transitionCoordinator != nil
                        || transitionController.transitionCoordinator != nil
                )
        }
        navigationController.beginRecording()

        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let completions = (0..<5).map { expectation(description: "rejected mutation \($0)") }
        var results: [Bool] = []

        func record(_ index: Int, _ isSuccess: Bool) {
            results.append(isSuccess)
            completions[index].fulfill()
        }

        navigator.navigate(
            destination: .controller(UIViewController()),
            strategy: .push(),
            animated: false,
            completion: { _, isSuccess in record(0, isSuccess) }
        )
        navigator.navigate(
            destination: .controller(UIViewController()),
            strategy: .replaceNavigationRoot,
            animated: false,
            completion: { _, isSuccess in record(1, isSuccess) }
        )
        navigator.navigate(
            destination: .controller(transitionController),
            strategy: .closeIfTop(tryToDismiss: false),
            animated: false,
            completion: { _, isSuccess in record(2, isSuccess) }
        )
        navigator.navigate(
            destination: .controller(rootController),
            strategy: .removeFromNavigationStack,
            animated: false,
            completion: { _, isSuccess in record(3, isSuccess) }
        )
        navigator.navigate(
            destination: .controller(rootController),
            strategy: .popToExisting(includingTabs: false),
            animated: false,
            completion: { _, isSuccess in record(4, isSuccess) }
        )

        await fulfillment(of: completions, timeout: 10)

        #expect(results == Array(repeating: false, count: 5))
        #expect(navigationController.pushAttempts == 0)
        #expect(navigationController.setViewControllersAttempts == 0)
        #expect(navigationController.popAttempts == 0)
        #expect(navigationController.popToAttempts == 0)
        #expect(navigationController.viewControllers == [rootController, transitionController])

        transitionDelegate.finishTransition()
        await waitUntil("external transition completion", timeout: 10) {
            navigationController.transitionCoordinator == nil
        }
    }

    @Test
    func `Navigation rejects a controller owned by another window`() async {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let windowScene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            Issue.record("Missing window scene")

            return
        }

        let foreignController = UIViewController()
        let foreignWindow = UIWindow(windowScene: windowScene)
        foreignWindow.rootViewController = foreignController
        foreignWindow.isHidden = false

        let rootController = UIViewController()
        let navigationController = MutationRecordingNavigationController(rootViewController: rootController)
        let navigationWindow = UIWindow(windowScene: windowScene)
        navigationWindow.rootViewController = navigationController
        navigationWindow.makeKeyAndVisible()
        defer {
            navigationWindow.isHidden = true
            foreignWindow.isHidden = true
        }
        _ = foreignController.view
        _ = navigationController.view
        navigationWindow.layoutIfNeeded()
        foreignWindow.layoutIfNeeded()
        await waitUntil("foreign window hierarchy", timeout: 10) {
            foreignController.viewIfLoaded?.window === foreignWindow
        }
        navigationController.beginRecording()

        let navigator = Navigator(window: navigationWindow, screenFactory: MockScreenFactory())
        let completions = (0..<4).map { expectation(description: "foreign controller rejection \($0)") }
        var results: [Bool] = []
        var popoverConfigurationCount = 0

        func record(_ index: Int, _ isSuccess: Bool) {
            results.append(isSuccess)
            completions[index].fulfill()
        }

        navigator.navigate(
            destination: .controller(foreignController),
            strategy: .push(),
            animated: false,
            completion: { _, isSuccess in record(0, isSuccess) }
        )
        navigator.navigate(
            destination: .controller(foreignController),
            strategy: .replaceNavigationRoot,
            animated: false,
            completion: { _, isSuccess in record(1, isSuccess) }
        )
        navigator.navigate(
            destination: .controller(foreignController),
            strategy: .present(),
            animated: false,
            completion: { _, isSuccess in record(2, isSuccess) }
        )
        navigator.navigate(
            destination: .controller(foreignController),
            strategy: .popover(configure: { _, _ in popoverConfigurationCount += 1 }),
            animated: false,
            completion: { _, isSuccess in record(3, isSuccess) }
        )

        await fulfillment(of: completions, timeout: 10)

        #expect(results == Array(repeating: false, count: 4))
        #expect(popoverConfigurationCount == 0)
        #expect(navigationController.pushAttempts == 0)
        #expect(navigationController.setViewControllersAttempts == 0)
        #expect(navigationController.viewControllers == [rootController])
        #expect(foreignWindow.rootViewController === foreignController)
        #expect(foreignController.viewIfLoaded?.window === foreignWindow)
    }

    @Test
    func `Large synchronous queue drains without recursive scheduler growth`() async {
        let window = UIWindow()
        let activeController = SuspendedResponderViewController()
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let activeCompletion = expectation(description: "queue stress active navigation")
        let queueCompletion = expectation(description: "queue stress drain")
        let queuedCount = 2_000
        var completionCount = 0

        navigator.navigate(
            destination: .controller(activeController),
            strategy: .replaceWindowRoot(),
            animated: false,
            event: SuspendedResponderEvent(),
            completion: { _, isSuccess in
                #expect(isSuccess)
                activeCompletion.fulfill()
            }
        )
        for _ in 0..<queuedCount {
            navigator.navigate(chain: []) { _, isSuccess in
                #expect(!isSuccess)
                completionCount += 1
                if completionCount == queuedCount {
                    queueCompletion.fulfill()
                }
            }
        }

        await waitUntil("queue stress suspension", timeout: 10) {
            activeController.isSuspended
        }
        activeController.resume()
        await fulfillment(of: [activeCompletion, queueCompletion], timeout: 10)

        #expect(completionCount == queuedCount)
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

@MainActor
private struct SuspendedResponderEvent: ResponderEvent {}

private final class WeakReference<Value: AnyObject> {
    weak var value: Value?

    init(_ value: Value?) {
        self.value = value
    }
}

private final class SuspendedResponderViewController: UIViewController, Responder {
    var nextEventResponder: (any Responder)?
    private var continuation: CheckedContinuation<Void, Never>?

    var isSuspended: Bool { continuation != nil }

    func handle(event: any ResponderEvent) async -> Bool {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }

        return true
    }

    func resume() {
        let continuation = self.continuation
        self.continuation = nil
        continuation?.resume()
    }
}

private final class HoldingNavigationTransitionDelegate: NSObject, UINavigationControllerDelegate {
    private let animator = HoldingNavigationAnimator()

    var hasActiveTransition: Bool { animator.hasActiveTransition }

    func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> (any UIViewControllerAnimatedTransitioning)? {
        operation == .push ? animator : nil
    }

    func finishTransition() {
        animator.finishTransition()
    }
}

private final class HoldingNavigationAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private var transitionContext: (any UIViewControllerContextTransitioning)?

    var hasActiveTransition: Bool { transitionContext != nil }

    func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
        30
    }

    func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
        guard let toController = transitionContext.viewController(forKey: .to),
            let toView = transitionContext.view(forKey: .to)
        else {
            transitionContext.completeTransition(false)

            return
        }

        toView.frame = transitionContext.finalFrame(for: toController)
        transitionContext.containerView.addSubview(toView)
        self.transitionContext = transitionContext
    }

    func finishTransition() {
        guard let transitionContext else { return }

        self.transitionContext = nil
        transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
    }
}

private final class HoldingDismissalTransitionDelegate: NSObject, UIViewControllerTransitioningDelegate {
    private let animator = HoldingDismissalAnimator()

    var hasActiveTransition: Bool { animator.hasActiveTransition }

    func animationController(
        forDismissed dismissed: UIViewController
    ) -> (any UIViewControllerAnimatedTransitioning)? {
        animator
    }

    func finishTransition() {
        animator.finishTransition()
    }
}

private final class HoldingDismissalAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private var transitionContext: (any UIViewControllerContextTransitioning)?

    var hasActiveTransition: Bool { transitionContext != nil }

    func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
        30
    }

    func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
        self.transitionContext = transitionContext
    }

    func finishTransition() {
        guard let transitionContext else { return }

        self.transitionContext = nil
        transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
    }
}

@MainActor
private final class FalseReturningCoordinatorNavigationController: UINavigationController {
    private let fakeCoordinator = FalseReturningTransitionCoordinator()
    private var exposesFakeCoordinator = false

    override var transitionCoordinator: (any UIViewControllerTransitionCoordinator)? {
        exposesFakeCoordinator ? fakeCoordinator : super.transitionCoordinator
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        super.pushViewController(viewController, animated: false)
        exposesFakeCoordinator = true
    }
}

@MainActor
private final class FalseReturningTransitionCoordinator: NSObject, UIViewControllerTransitionCoordinator {
    var isAnimated: Bool { true }
    var presentationStyle: UIModalPresentationStyle { .none }
    var initiallyInteractive: Bool { false }
    var isInterruptible: Bool { false }
    var isInteractive: Bool { false }
    var isCancelled: Bool { false }
    var transitionDuration: TimeInterval { 0 }
    var percentComplete: CGFloat { 1 }
    var completionVelocity: CGFloat { 1 }
    var completionCurve: UIView.AnimationCurve { .linear }
    let containerView = UIView()
    var targetTransform: CGAffineTransform { .identity }

    func viewController(forKey key: UITransitionContextViewControllerKey) -> UIViewController? {
        nil
    }

    func view(forKey key: UITransitionContextViewKey) -> UIView? {
        nil
    }

    func animate(
        alongsideTransition animation: ((any UIViewControllerTransitionCoordinatorContext) -> Void)?,
        completion: ((any UIViewControllerTransitionCoordinatorContext) -> Void)?
    ) -> Bool {
        completion?(self)

        return false
    }

    func animateAlongsideTransition(
        in view: UIView?,
        animation: ((any UIViewControllerTransitionCoordinatorContext) -> Void)?,
        completion: ((any UIViewControllerTransitionCoordinatorContext) -> Void)?
    ) -> Bool {
        completion?(self)

        return false
    }

    func notifyWhenInteractionEnds(
        _ handler: @escaping (any UIViewControllerTransitionCoordinatorContext) -> Void
    ) {
        handler(self)
    }

    func notifyWhenInteractionChanges(
        _ handler: @escaping (any UIViewControllerTransitionCoordinatorContext) -> Void
    ) {
        handler(self)
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
    private(set) var popAttempts = 0
    private(set) var popToAttempts = 0

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

    override func popViewController(animated: Bool) -> UIViewController? {
        guard isRecording else {
            return super.popViewController(animated: animated)
        }

        popAttempts += 1

        return nil
    }

    override func popToViewController(
        _ viewController: UIViewController,
        animated: Bool
    ) -> [UIViewController]? {
        guard isRecording else {
            return super.popToViewController(viewController, animated: animated)
        }

        popToAttempts += 1

        return nil
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
