//
//  Navigator.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

@MainActor
public final class Navigator {
    public let screenFactory: any NavigatorScreenFactory
    /// Receives a typed diagnostic whenever a navigation strategy attempt is rejected.
    ///
    /// The handler runs synchronously on the main actor before a configured fallback is attempted. Assigning a handler
    /// is optional and does not change existing completion results or fallback behavior.
    public var navigationFailureHandler: ((NavigationFailure) -> Void)?
    public var navigationInterceptor: NavigationInterceptor? {
        didSet {
            guard oldValue !== navigationInterceptor else { return }

            oldValue?.removeNavigations(for: self)
        }
    }

    public private(set) weak var window: UIWindow?

    private var navigationQueue = Queue<QueuedNavigatorWork>()
    private var activeNavigationOperation: NavigationOperation? {
        didSet { checkQueue() }
    }
    private var isNavigationInProgress: Bool { activeNavigationOperation != nil }
    private var isChainNavigationInProgress = false {
        didSet { checkQueue() }
    }
    private var isQueueCheckSuspended = false
    private var isQueueCheckInProgress = false
    public init(
        window: UIWindow?,
        screenFactory: any NavigatorScreenFactory,
        navigationInterceptor: NavigationInterceptor? = nil
    ) {
        self.window = window
        self.screenFactory = screenFactory
        self.navigationInterceptor = navigationInterceptor
    }

    isolated deinit {
        navigationInterceptor?.removeNavigations(for: self)
    }

    /// Navigates through a chain of destinations.
    ///
    /// - Parameters:
    ///   - chain: An array of navigation links representing the navigation chain with destination and strategy.
    ///   - event: `ResponderEvent` to be handled by the destination controller.
    ///   - completion: A closure called with the responder and result after navigation completes.
    public func navigate(
        chain: [NavigationChainLink],
        event: (any ResponderEvent)? = nil,
        completion: ((UIViewController?, Bool) -> Void)? = nil
    ) {
        enqueueOrStartNavigationChain(
            chain: chain,
            event: event,
            initialResult: nil,
            completion: completion
        )
    }

    @available(*, deprecated, message: "linkCompletionResult is internal navigation state and is no longer needed")
    public func navigate(
        chain: [NavigationChainLink],
        event: (any ResponderEvent)? = nil,
        linkCompletionResult: (UIViewController?, Bool)?,
        completion: ((UIViewController?, Bool) -> Void)? = nil
    ) {
        enqueueOrStartNavigationChain(
            chain: chain,
            event: event,
            initialResult: linkCompletionResult,
            completion: completion
        )
    }

    private func enqueueOrStartNavigationChain(
        chain: [NavigationChainLink],
        event: (any ResponderEvent)?,
        initialResult: (UIViewController?, Bool)?,
        completion: ((UIViewController?, Bool) -> Void)?
    ) {
        guard !(isChainNavigationInProgress || isNavigationInProgress) else {
            navigationQueue.enqueue(
                .navigation(QueuedNavigation(
                    chain: chain,
                    event: event,
                    completion: completion,
                    initialResult: initialResult
                ))
            )

            return
        }

        isChainNavigationInProgress = true
        continueNavigationChain(
            chain: chain,
            linkIndex: chain.startIndex,
            event: event,
            linkCompletionResult: initialResult,
            completion: completion
        )
    }

    private func continueNavigationChain(
        chain: [NavigationChainLink],
        linkIndex: Int,
        event: (any ResponderEvent)?,
        linkCompletionResult: (UIViewController?, Bool)?,
        completion: ((UIViewController?, Bool) -> Void)?
    ) {
        guard linkIndex < chain.endIndex else {
            completion?(linkCompletionResult?.0, linkCompletionResult?.1 ?? false)
            isChainNavigationInProgress = false

            return
        }

        let link = chain[linkIndex]
        let nextLinkIndex = chain.index(after: linkIndex)
        if let navigationInterceptor,
            let interceptionResult = navigationInterceptor.intercept(
                destination: link.destination
            )
        {
            let detail = InterceptedNavigation(
                chain: Array(chain[linkIndex...]),
                event: event,
                completion: completion,
                navigator: self
            )
            navigationInterceptor.store(detail, reason: interceptionResult.reason)
            performSuspendingQueueCheck {
                isChainNavigationInProgress = false
                navigate(
                    chain: interceptionResult.chain,
                    event: interceptionResult.event,
                    completion: nil
                )
            }

            return
        }

        navigate(
            to: link.destination,
            strategy: link.strategy,
            animated: link.animated,
            fallback: link.fallback,
            event: event,
            chainContext: NavigationChainContext(
                remainingLinks: chain[nextLinkIndex...],
                completion: completion
            ),
            shouldIntercept: false,
            completion: { [self] controller, result in
                guard result else {
                    completion?(controller, false)
                    self.isChainNavigationInProgress = false

                    return
                }

                Task { @MainActor [self] in
                    continueNavigationChain(
                        chain: chain,
                        linkIndex: nextLinkIndex,
                        event: event,
                        linkCompletionResult: (controller, result),
                        completion: completion
                    )
                }
            }
        )
    }

    /// Navigates to a specific destination using the provided navigation strategy.
    ///
    /// - Parameters:
    ///   - destination: The destination to navigate to.
    ///   - strategy: The navigation strategy to be applied.
    ///   - animated: A flag indicating whether the navigation should be animated.
    ///   - fallbackStrategies: The fallback navigation strategies.
    ///   - event: `ResponderEvent` to be handled by the destination controller.
    ///   - completion: A closure called with the responder and result after navigation completes.
    /// - Note: Popover navigation without a configured source item, source view, or bar button item fails safely
    ///   and uses the supplied fallback, when available.
    public func navigate(
        destination: NavigationDestination,
        strategy: NavigationStrategy,
        animated: Bool = true,
        fallbackStrategies: [NavigationStrategy],
        event: (any ResponderEvent)? = nil,
        completion: ((UIViewController?, Bool) -> Void)? = nil
    ) {
        navigate(
            destination: destination,
            strategy: strategy,
            animated: animated,
            fallback: makeFallbackChain(
                destination: destination,
                animated: animated,
                fallbackStrategies: fallbackStrategies
            ),
            event: event,
            completion: completion
        )
    }

    /// Navigates to a specific destination using the provided navigation strategy.
    ///
    /// - Parameters:
    ///   - destination: The destination to navigate to.
    ///   - strategy: The navigation strategy to be applied.
    ///   - animated: A flag indicating whether the navigation should be animated.
    ///   - fallback: The fallback navigation chain link.
    ///   - event: `ResponderEvent` to be handled by the destination controller.
    ///   - completion: A closure called with the responder and result after navigation completes.
    /// - Note: Popover navigation without a configured source item, source view, or bar button item fails safely
    ///   and uses `fallback`, when supplied.
    public func navigate(
        destination: NavigationDestination,
        strategy: NavigationStrategy,
        animated: Bool = true,
        fallback: NavigationChainLink? = nil,
        event: (any ResponderEvent)? = nil,
        completion: ((UIViewController?, Bool) -> Void)? = nil
    ) {
        guard !(isChainNavigationInProgress || isNavigationInProgress) else {
            navigationQueue.enqueue(
                .navigation(QueuedNavigation(
                    chain: [
                        NavigationChainLink(
                            destination: destination,
                            strategy: strategy,
                            animated: animated,
                            fallback: fallback
                        )
                    ],
                    event: event,
                    completion: completion,
                    initialResult: nil
                ))
            )

            return
        }

        let operation = NavigationOperation()
        activeNavigationOperation = operation
        navigate(
            to: destination,
            strategy: strategy,
            animated: animated,
            fallback: fallback,
            event: event,
            completion: { [weak self] controller, result in
                completion?(controller, result)
                self?.finishNavigationOperation(operation)
            }
        )
    }

    func navigate(
        to destination: NavigationDestination,
        strategy: NavigationStrategy,
        animated: Bool,
        fallback: NavigationChainLink?,
        event: (any ResponderEvent)?,
        chainContext: NavigationChainContext? = nil,
        shouldIntercept: Bool = true,
        shouldReportFailure: Bool = true,
        completion: ((UIViewController?, Bool) -> Void)?
    ) {
        if shouldIntercept,
            let navigationInterceptor,
            let interceptionResult = navigationInterceptor.intercept(
                destination: destination
            )
        {
            let currentLink = NavigationChainLink(
                destination: destination,
                strategy: strategy,
                animated: animated,
                fallback: fallback
            )
            let interceptedCompletion: ((UIViewController?, Bool) -> Void)?
            if let chainContext {
                interceptedCompletion = chainContext.completion
            } else {
                interceptedCompletion = completion
            }
            let detail = InterceptedNavigation(
                chain: [currentLink] + (chainContext.map { Array($0.remainingLinks) } ?? []),
                event: event,
                completion: interceptedCompletion,
                navigator: self
            )
            navigationInterceptor.store(detail, reason: interceptionResult.reason)
            performSuspendingQueueCheck {
                if isChainNavigationInProgress {
                    isChainNavigationInProgress = false
                } else {
                    activeNavigationOperation = nil
                }
                navigate(
                    chain: interceptionResult.chain,
                    event: interceptionResult.event,
                    completion: nil
                )
            }

            return
        }

        executeNavigation(
            NavigationExecution(
                destination: destination,
                strategy: strategy,
                animated: animated,
                fallback: fallback,
                event: event,
                chainContext: chainContext,
                shouldReportFailure: shouldReportFailure,
                completion: completion
            )
        )
    }
    /// Retrieves a view controller based on the provided navigation destination.
    ///
    /// - Parameter destination: A destination that either assembles a screen by identity or supplies a controller.
    /// - Returns: The view controller corresponding to the given navigation destination.
    func getController(destination: NavigationDestination) -> UIViewController {
        switch destination {
        case let .identity(identity):
            let controller = screenFactory.assembleScreen(identity: identity, navigator: self)
            controller.navigationIdentity = identity

            return controller
        case let .controller(controller):
            return controller
        }
    }

    /// Pushes a view controller onto the top navigation stack after dismissing presented controllers.
    ///
    /// - Parameters:
    ///   - sourceController: The source controller from which presented controllers will be dismissed.
    ///   - controller: The view controller to push onto the navigation stack.
    ///   - animated: Should be animated or not.
    ///   - completion: A closure called with `true` after a successful push, or `false` if the push is invalid.
    public func push(
        sourceController: UIViewController?,
        controller: UIViewController,
        animated: Bool,
        navigation: ((UINavigationController) -> Void)?,
        completion: ((Bool) -> Void)?
    ) {
        enqueueOrStartNavigationOperation { [self] finish in
            pushNow(
                sourceController: sourceController,
                controller: controller,
                animated: animated,
                navigation: navigation,
                completion: { result in
                    if case let .failure(reason) = result {
                        self.reportNavigationFailure(
                            reason: reason,
                            destination: .controller(controller),
                            strategy: .push()
                        )
                    }
                    completion?(result.isSuccess)
                    finish()
                }
            )
        }
    }

    func pushNow(
        sourceController: UIViewController?,
        controller: UIViewController,
        animated: Bool,
        navigation: ((UINavigationController) -> Void)?,
        completion: ((Result<Void, NavigationFailure.Reason>) -> Void)?
    ) {
        dismissPresentedNow(
            in: sourceController,
            animated: animated,
            completion: { [self] dismissalResult in
                guard case .success = dismissalResult else {
                    completion?(
                        .failure(dismissalResult.failureReason ?? .dismissalRejected)
                    )

                    return
                }

                if let navigationController = window?.topController?.orNavigationController {
                    push(
                        controller: controller,
                        to: navigationController,
                        animated: animated,
                        navigation: navigation,
                        completion: completion
                    )
                } else {
                    completion?(.failure(.navigationControllerUnavailable))
                }
            }
        )
    }

    func push(
        controller: UIViewController,
        to navigationController: UINavigationController,
        animated: Bool,
        navigation: ((UINavigationController) -> Void)?,
        completion: ((Result<Void, NavigationFailure.Reason>) -> Void)?
    ) {
        navigation?(navigationController)
        guard navigationController.canPushViewController(controller) else {
            completion?(
                .failure(
                    navigationController.canMutateNavigationStack
                        ? .invalidDestinationHierarchy
                        : .transitionInProgress
                )
            )

            return
        }

        navigationController.pushViewController(
            controller,
            animated: animated,
            completion: {
                let didPush = navigationController.topViewController === controller
                    && navigationController.viewControllers.contains(where: { $0 === controller })
                completion?(didPush ? .success(()) : .failure(.mutationRejected))
            }
        )
    }

    /// Replaces the root view controller of the window or sets it as the initial root view controller.
    ///
    /// - Parameters:
    ///   - controller: The view controller to set as the `rootViewController`.
    ///   - transition: Animated transitions when replacing the `rootViewController`.
    ///   - completion: A closure to be executed after the replacement is complete.
    func replaceWindowRoot(
        controller: UIViewController,
        transition: CATransition?,
        completion: (() -> Void)?
    ) {
        guard let window else {
            completion?()

            return
        }

        guard window.canSetNavigatorRootViewController(controller) else {
            completion?()

            return
        }

        if window.rootViewController == nil {
            window.rootViewController = controller
            window.makeKeyAndVisible()

            completion?()
        } else {
            window.set(
                rootViewController: controller,
                transition: transition,
                completion: completion
            )
        }
    }

    /// Dismisses presented view controllers and pops to the specified controller when it belongs to the stack.
    ///
    /// - Parameters:
    ///   - controller: Controller with presented controllers to dismiss and the target for navigation stack pop.
    ///   - animated: Should be animated or not.
    ///   - completion: A closure to be executed after controllers are dismissed.
    public func closeNavigationPresented(controller: UIViewController?, animated: Bool, completion: (() -> Void)?) {
        enqueueOrStartNavigationOperation { [self] finish in
            closeNavigationPresentedResult(
                controller: controller,
                animated: animated,
                completion: { result in
                    if case let .failure(reason) = result {
                        self.reportNavigationFailure(
                            reason: reason,
                            destination: controller.map(NavigationDestination.controller)
                        )
                    }
                    completion?()
                    finish()
                }
            )
        }
    }

    func closeNavigationPresentedResult(
        controller: UIViewController?,
        animated: Bool,
        completion: @escaping (Result<Void, NavigationFailure.Reason>) -> Void
    ) {
        guard let controller else {
            completion(.failure(.sourceViewControllerUnavailable))

            return
        }

        dismissPresentedNow(
            in: controller,
            animated: animated,
            completion: { dismissalResult in
                guard case .success = dismissalResult else {
                    completion(
                        .failure(dismissalResult.failureReason ?? .dismissalRejected)
                    )

                    return
                }

                guard let navigationController = controller.orNavigationController else {
                    completion(.success(()))

                    return
                }

                if controller === navigationController {
                    completion(.success(()))

                    return
                }

                let popTarget = navigationController.viewControllers.first {
                    $0 === controller || $0.findController(controller: controller, withPresented: false) != nil
                }
                guard let popTarget else {
                    completion(.failure(.invalidDestinationHierarchy))

                    return
                }

                navigationController.popToViewController(
                    popTarget,
                    animated: animated,
                    resultCompletion: { didPop in
                        completion(didPop ? .success(()) : .failure(.mutationRejected))
                    }
                )
            }
        )
    }

    private func dismissPresentedNow(
        in controller: UIViewController?,
        animated: Bool,
        completion: @escaping (Result<Void, NavigationFailure.Reason>) -> Void
    ) {
        guard let controller, let presentedController = controller.presentedViewController else {
            completion(.success(()))

            return
        }

        dismissPresentedController(
            presentedController,
            animated: animated,
            completion: { [self] result in
                guard case .success = result else {
                    completion(result)

                    return
                }

                if controller.presentedViewController != nil {
                    dismissPresentedNow(
                        in: controller,
                        animated: animated,
                        completion: completion
                    )
                } else {
                    completion(.success(()))
                }
            }
        )
    }

    func dismissPresentedController(
        _ controller: UIViewController,
        animated: Bool,
        completion: @escaping (Result<Void, NavigationFailure.Reason>) -> Void
    ) {
        guard let presentingController = controller.presentingViewController else {
            completion(.failure(.dismissalRejected))

            return
        }
        guard !containsActiveTransition(in: controller),
            !containsActiveTransition(in: presentingController)
        else {
            completion(.failure(.transitionInProgress))

            return
        }

        let previouslyPresentedController = controller.presentedViewController
        controller.dismiss(
            animated: animated,
            completion: {
                DispatchQueue.main.async {
                    let controllerWasDetached =
                        controller.presentingViewController == nil
                        && presentingController.presentedViewController !== controller
                    let presentedHierarchyChanged = previouslyPresentedController.map {
                        controller.presentedViewController !== $0
                    } ?? false
                    completion(
                        controllerWasDetached || presentedHierarchyChanged
                            ? .success(())
                            : .failure(.dismissalRejected)
                    )
                }
            }
        )
    }

    func dismissVisiblePresentationsOutsideHierarchy(
        of controller: UIViewController,
        animated: Bool,
        completion: @escaping (Result<Void, NavigationFailure.Reason>) -> Void
    ) {
        guard let presentedController = visiblePresentationOutsideHierarchy(of: controller) else {
            completion(.success(()))

            return
        }

        dismissPresentedController(
            presentedController,
            animated: animated,
            completion: { [self] result in
                guard case .success = result else {
                    completion(result)

                    return
                }

                dismissVisiblePresentationsOutsideHierarchy(
                    of: controller,
                    animated: animated,
                    completion: completion
                )
            }
        )
    }

    private func containsActiveTransition(in controller: UIViewController) -> Bool {
        if controller.isBeingPresented
            || controller.isBeingDismissed
            || controller.transitionCoordinator != nil
        {
            return true
        }
        if controller.children.contains(where: containsActiveTransition(in:)) {
            return true
        }
        if let presentedViewController = controller.presentedViewController {
            return containsActiveTransition(in: presentedViewController)
        }

        return false
    }

    private func visiblePresentationOutsideHierarchy(of controller: UIViewController) -> UIViewController? {
        guard let topController = window?.topController,
            var presentedController = presentedAncestor(startingAt: topController),
            !presentedController.containsInNavigatorHierarchy(controller)
        else {
            return nil
        }

        var visitedControllers = Set<ObjectIdentifier>([ObjectIdentifier(presentedController)])
        while let presentingController = presentedController.presentingViewController,
            let outerPresentedController = presentedAncestor(startingAt: presentingController),
            visitedControllers.insert(ObjectIdentifier(outerPresentedController)).inserted
        {
            guard !outerPresentedController.containsInNavigatorHierarchy(controller) else { break }
            presentedController = outerPresentedController
        }

        return presentedController
    }

    func presentedAncestor(startingAt controller: UIViewController) -> UIViewController? {
        var candidate: UIViewController? = controller
        var visitedControllers = Set<ObjectIdentifier>()
        while let currentController = candidate,
            visitedControllers.insert(ObjectIdentifier(currentController)).inserted
        {
            if currentController.presentingViewController != nil {
                return currentController
            }
            candidate = currentController.parent
        }

        return nil
    }

    /// Dismisses all presented view controllers within the given controller while they are being presented.
    ///
    /// - Parameters:
    ///   - controller: Controller with presented controllers to dismiss.
    ///   - animated: Should be animated or not.
    ///   - completion: A closure to be executed after the controller is dismissed.
    public func dismissPresented(
        in controller: UIViewController?,
        animated: Bool,
        completion: (() -> Void)?
    ) {
        enqueueOrStartNavigationOperation { [self] finish in
            dismissPresentedNow(
                in: controller,
                animated: animated,
                completion: { result in
                    if case let .failure(reason) = result {
                        self.reportNavigationFailure(
                            reason: reason,
                            destination: controller.map(NavigationDestination.controller)
                        )
                    }
                    completion?()
                    finish()
                }
            )
        }
    }

    /// Selects the tab in the tab bar controller, if needed, based on the provided source identity.
    ///
    /// - Parameters:
    ///   - controller: The view controller from which to start searching for the tab bar controller.
    ///   - completion: A closure to be executed after the tab is selected.
    public func selectTabIfNeeded(
        controller: UIViewController?,
        completion: (() -> Void)? = nil
    ) {
        enqueueOrStartNavigationOperation { [self] finish in
            selectTabIfNeededNow(
                controller: controller,
                completion: {
                    completion?()
                    finish()
                }
            )
        }
    }

    func selectTabIfNeededNow(
        controller: UIViewController?,
        completion: (() -> Void)? = nil
    ) {
        guard let controller else {
            completion?()

            return
        }

        var selectionTarget = controller
        var tabBarController = controller.findTabBarController()
        var selectedTabControllers = Set<ObjectIdentifier>()
        while let currentTabBarController = tabBarController,
            selectedTabControllers.insert(ObjectIdentifier(currentTabBarController)).inserted
        {
            if let index = currentTabBarController.viewControllers?.firstIndex(where: {
                $0 === selectionTarget
                    || $0.findController(controller: selectionTarget, withPresented: false) != nil
            }), currentTabBarController.selectedIndex != index {
                currentTabBarController.selectedIndex = index
            }

            selectionTarget = currentTabBarController
            var ancestor = currentTabBarController.parent
            while ancestor != nil, !(ancestor is UITabBarController) {
                ancestor = ancestor?.parent
            }
            tabBarController = ancestor as? UITabBarController
        }

        completion?()
    }

    public func makeFallbackChain(
        destination: NavigationDestination,
        animated: Bool,
        fallbackStrategies: [NavigationStrategy]
    ) -> NavigationChainLink? {
        var fallbackChainLink: NavigationChainLink?
        for fallbackStrategy in fallbackStrategies.reversed() {
            let link = NavigationChainLink(
                destination: destination,
                strategy: fallbackStrategy,
                animated: animated,
                fallback: fallbackChainLink
            )
            fallbackChainLink = link
        }

        return fallbackChainLink
    }

    private func enqueueOrStartNavigationOperation(_ operation: @escaping QueuedNavigatorOperation) {
        guard !(isChainNavigationInProgress || isNavigationInProgress) else {
            navigationQueue.enqueue(.operation(operation))

            return
        }

        startNavigationOperation(operation)
    }

    private func startNavigationOperation(_ queuedOperation: QueuedNavigatorOperation) {
        let operation = NavigationOperation()
        activeNavigationOperation = operation
        queuedOperation { [self] in
            finishNavigationOperation(operation)
        }
    }

    private func checkQueue() {
        guard !isQueueCheckSuspended, !isQueueCheckInProgress else { return }

        isQueueCheckInProgress = true
        defer { isQueueCheckInProgress = false }
        while !isQueueCheckSuspended,
            !(isNavigationInProgress || isChainNavigationInProgress),
            let queued = navigationQueue.dequeue()
        {
            switch queued {
            case let .navigation(navigation):
                enqueueOrStartNavigationChain(
                    chain: navigation.chain,
                    event: navigation.event,
                    initialResult: navigation.initialResult,
                    completion: navigation.completion
                )
            case let .operation(operation):
                startNavigationOperation(operation)
            }
        }
    }

    private func finishNavigationOperation(_ operation: NavigationOperation) {
        guard activeNavigationOperation === operation else { return }

        activeNavigationOperation = nil
    }

    private func performSuspendingQueueCheck(_ operation: () -> Void) {
        let wasQueueCheckSuspended = isQueueCheckSuspended
        isQueueCheckSuspended = true
        operation()
        isQueueCheckSuspended = wasQueueCheckSuspended
        if !wasQueueCheckSuspended {
            checkQueue()
        }
    }

    func reportNavigationFailure(
        reason: NavigationFailure.Reason,
        destination: NavigationDestination? = nil,
        strategy: NavigationStrategy? = nil
    ) {
        navigationFailureHandler?(
            NavigationFailure(
                reason: reason,
                destination: destination,
                strategy: strategy
            )
        )
    }

}

private typealias QueuedNavigatorOperation = (@escaping () -> Void) -> Void

private enum QueuedNavigatorWork {
    case navigation(QueuedNavigation)
    case operation(QueuedNavigatorOperation)
}

private struct QueuedNavigation {
    let chain: [NavigationChainLink]
    let event: (any ResponderEvent)?
    let completion: ((UIViewController?, Bool) -> Void)?
    let initialResult: (UIViewController?, Bool)?
}

struct NavigationChainContext {
    let remainingLinks: ArraySlice<NavigationChainLink>
    let completion: ((UIViewController?, Bool) -> Void)?
}

private final class NavigationOperation {}

private extension UIViewController {
    func containsInNavigatorHierarchy(_ controller: UIViewController) -> Bool {
        self === controller || findController(controller: controller, withPresented: false) != nil
    }
}

extension Result where Success == Void, Failure == NavigationFailure.Reason {
    var isSuccess: Bool {
        if case .success = self {
            return true
        }

        return false
    }

    var failureReason: Failure? {
        guard case let .failure(reason) = self else { return nil }

        return reason
    }
}
