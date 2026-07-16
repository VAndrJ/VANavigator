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
    public var navigationInterceptor: NavigationInterceptor? {
        didSet {
            guard oldValue !== navigationInterceptor else { return }

            oldValue?.removeNavigations(for: self)
        }
    }

    public private(set) weak var window: UIWindow?

    private var navigationQueue = Queue<QueuedNavigation>()
    private var activeNavigationOperation: NavigationOperation? {
        didSet { checkQueue() }
    }
    private var isNavigationInProgress: Bool { activeNavigationOperation != nil }
    private var isChainNavigationInProgress = false {
        didSet { checkQueue() }
    }
    private var isQueueCheckSuspended = false
    private var isQueueCheckInProgress = false
    private let popoverDelegate = PopoverDelegate()

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
                QueuedNavigation(
                    chain: chain,
                    event: event,
                    completion: completion,
                    initialResult: initialResult
                )
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
                strategy: strategy,
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
                QueuedNavigation(
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
                )
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

    private func navigate(
        to destination: NavigationDestination,
        strategy: NavigationStrategy,
        animated: Bool,
        fallback: NavigationChainLink?,
        event: (any ResponderEvent)?,
        chainContext: NavigationChainContext? = nil,
        shouldIntercept: Bool = true,
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

        var navigatorEvent: (any ResponderEvent)?

        func perform(
            event: (any ResponderEvent)?,
            navigatorEvent: (any ResponderEvent)?,
            on responder: (any Responder)?,
            completion: @escaping () -> Void
        ) {
            guard let responder, navigatorEvent != nil || event != nil else {
                completion()

                return
            }

            Task { [self] in
                if let navigatorEvent {
                    _ = await responder.handle(event: navigatorEvent)
                }
                if let event {
                    _ = await responder.handle(event: event)
                }
                withExtendedLifetime(self) {
                    completion()
                }
            }
        }

        switch strategy {
        case _ as RemoveFromStackNavigationStrategy:
            func completeRemovalFailure() {
                if let fallback {
                    navigate(
                        to: fallback.destination,
                        strategy: fallback.strategy,
                        animated: fallback.animated,
                        fallback: fallback.fallback,
                        event: event,
                        chainContext: chainContext,
                        completion: completion
                    )
                } else {
                    completion?(nil, false)
                }
            }

            if let navigationController = window?.topController?.orNavigationController,
                navigationController.canMutateNavigationStack
            {
                if navigationController.topViewController.map({
                    destination.isEqual(to: .controller($0))
                }) == true {
                    navigate(
                        to: destination,
                        strategy: .closeIfTop(tryToDismiss: false),
                        animated: animated,
                        fallback: nil,
                        event: event,
                        chainContext: chainContext,
                        shouldIntercept: false,
                        completion: { controller, isSuccess in
                            if isSuccess {
                                completion?(controller, true)
                            } else {
                                completeRemovalFailure()
                            }
                        }
                    )
                } else if let index = navigationController.viewControllers.firstIndex(
                    where: { destination.isEqual(to: .controller($0)) }
                ) {
                    let removedController = navigationController.viewControllers[index]
                    let previousCount = navigationController.viewControllers.count
                    navigationController.viewControllers.remove(at: index)

                    if navigationController.viewControllers.count == previousCount - 1,
                        !navigationController.viewControllers.contains(where: { $0 === removedController })
                    {
                        completion?(nil, true)
                    } else {
                        completeRemovalFailure()
                    }
                } else {
                    completeRemovalFailure()
                }
            } else {
                completeRemovalFailure()
            }
        case let strategy as CloseIfTopNavigationStrategy:
            let tryToPop = strategy.tryToPop
            let tryToDismiss = strategy.tryToDismiss
            func isMatchingDestination(_ controller: UIViewController?) -> Bool {
                controller.map { destination.isEqual(to: .controller($0)) } ?? false
            }
            func presentedContainer(for controller: UIViewController) -> UIViewController? {
                if let navigationController = controller.orNavigationController,
                    navigationController.presentingViewController != nil
                {
                    return navigationController
                } else if controller.presentingViewController != nil {
                    return controller
                }

                return nil
            }
            func completeCloseFailure() {
                if let fallback {
                    navigate(
                        to: fallback.destination,
                        strategy: fallback.strategy,
                        animated: fallback.animated,
                        fallback: fallback.fallback,
                        event: event,
                        chainContext: chainContext,
                        completion: completion
                    )
                } else {
                    completion?(nil, false)
                }
            }
            func completeCloseSuccess() {
                withExtendedLifetime(self) {
                    completion?(nil, true)
                }
            }

            if let controller = window?.topController {
                if tryToPop,
                    let navigationController = controller.orNavigationController,
                    isMatchingDestination(navigationController.topViewController)
                {
                    strategy.navigation?(navigationController)
                    navigationController.popViewController(
                        animated: animated,
                        completion: { isSuccess in
                            if isSuccess {
                                completeCloseSuccess()
                            } else if tryToDismiss, let presentedController = presentedContainer(for: controller) {
                                presentedController.dismiss(
                                    animated: animated,
                                    completion: completeCloseSuccess
                                )
                            } else {
                                completeCloseFailure()
                            }
                        }
                    )
                } else {
                    if tryToDismiss,
                        isMatchingDestination(controller),
                        let presentedController = presentedContainer(for: controller)
                    {
                        presentedController.dismiss(
                            animated: animated,
                            completion: completeCloseSuccess
                        )
                    } else {
                        completeCloseFailure()
                    }
                }
            } else {
                completeCloseFailure()
            }
        case let strategy as ReplaceWindowRootNavigationStrategy:
            func completeWindowRootFailure() {
                if let fallback {
                    navigate(
                        to: fallback.destination,
                        strategy: fallback.strategy,
                        animated: fallback.animated,
                        fallback: fallback.fallback,
                        event: event,
                        chainContext: chainContext,
                        completion: completion
                    )
                } else {
                    completion?(nil, false)
                }
            }

            guard let window else {
                completeWindowRootFailure()

                return
            }

            let transition = animated ? strategy.transition : nil
            let controller = getController(destination: destination)
            let currentRootController = window.rootViewController
            guard window.canSetNavigatorRootViewController(controller) else {
                completeWindowRootFailure()

                return
            }

            if currentRootController != nil, currentRootController !== controller {
                navigatorEvent = ResponderReplacedWindowRootControllerEvent()
            }

            func completeWindowRootSuccess() {
                perform(
                    event: event,
                    navigatorEvent: navigatorEvent,
                    on: controller as? any UIViewController & Responder,
                    completion: {
                        completion?(controller, true)
                    }
                )
            }

            replaceWindowRoot(
                controller: controller,
                transition: transition,
                completion: {
                    guard window.rootViewController === controller else {
                        completeWindowRootFailure()

                        return
                    }

                    completeWindowRootSuccess()
                }
            )
        case let strategy as PresentNavigationStrategy:
            func completePresentationFailure() {
                if let fallback {
                    navigate(
                        to: fallback.destination,
                        strategy: fallback.strategy,
                        animated: fallback.animated,
                        fallback: fallback.fallback,
                        event: event,
                        chainContext: chainContext,
                        completion: completion
                    )
                } else {
                    completion?(nil, false)
                }
            }

            if window?.rootViewController != nil {
                let sourceController: UIViewController?
                switch strategy.source {
                case .topController:
                    sourceController = window?.topController
                case .navigationController:
                    sourceController = window?.topController?.orNavigationController
                case .tabBarController:
                    sourceController = window?.topController?.orTabBarController
                }
                func presentableSource(from controller: UIViewController?) -> UIViewController? {
                    guard let controller else { return nil }
                    if controller.viewIfLoaded?.window != nil || controller === window?.rootViewController {
                        return controller
                    } else if let navigationController = controller.orNavigationController,
                        navigationController.viewIfLoaded?.window != nil
                    {
                        return navigationController
                    } else if let tabBarController = controller.orTabBarController,
                        tabBarController.viewIfLoaded?.window != nil
                    {
                        return tabBarController
                    } else {
                        var visibleController = window?.rootViewController
                        while let presentedController = visibleController?.presentedViewController,
                            !presentedController.isBeingDismissed
                        {
                            visibleController = presentedController
                        }

                        return visibleController
                    }
                }

                if let sourceController = presentableSource(from: sourceController) {
                    let controller = getController(destination: destination)
                    guard controller !== sourceController,
                        controller.parent == nil,
                        controller.presentingViewController == nil,
                        controller.presentedViewController == nil,
                        controller.transitionCoordinator == nil,
                        controller.viewIfLoaded?.window == nil,
                        controller.findController(controller: sourceController, withPresented: true) == nil,
                        sourceController.presentedViewController == nil,
                        !sourceController.isBeingDismissed,
                        !sourceController.isBeingPresented
                    else {
                        completePresentationFailure()

                        return
                    }

                    sourceController.present(
                        controller,
                        animated: animated,
                        completion: {
                            let isPresented =
                                controller.presentingViewController != nil
                                || sourceController.presentedViewController === controller
                            guard isPresented else {
                                completePresentationFailure()

                                return
                            }

                            perform(
                                event: event,
                                navigatorEvent: navigatorEvent,
                                on: controller as? any UIViewController & Responder,
                                completion: {
                                    completion?(controller, true)
                                }
                            )
                        }
                    )
                } else {
                    completePresentationFailure()
                }
            } else {
                completePresentationFailure()
            }
        case _ as CloseToExistingNavigationStrategy:
            func completeCloseFailure() {
                if let fallback {
                    navigate(
                        to: fallback.destination,
                        strategy: fallback.strategy,
                        animated: fallback.animated,
                        fallback: fallback.fallback,
                        event: event,
                        chainContext: chainContext,
                        completion: completion
                    )
                } else {
                    completion?(nil, false)
                }
            }

            if let controller = window?.findController(destination: destination) {
                navigatorEvent = ResponderClosedToExistingEvent()
                selectTabIfNeeded(
                    controller: controller,
                    completion: { [self] in
                        closeNavigationPresentedResult(
                            controller: controller,
                            animated: animated,
                            completion: { isSuccess in
                                guard isSuccess else {
                                    completeCloseFailure()

                                    return
                                }

                                perform(
                                    event: event,
                                    navigatorEvent: navigatorEvent,
                                    on: controller as? any UIViewController & Responder,
                                    completion: {
                                        completion?(controller, true)
                                    }
                                )
                            }
                        )
                    }
                )
            } else {
                completeCloseFailure()
            }
        case let strategy as PushNavigationStrategy:
            let controller = getController(destination: destination)
            let sourceController = window?.topController?.orNavigationController ?? window?.rootViewController
            push(
                sourceController: sourceController,
                controller: controller,
                animated: animated,
                navigation: strategy.navigation,
                completion: { [self] isSuccess in
                    if isSuccess {
                        perform(
                            event: event,
                            navigatorEvent: navigatorEvent,
                            on: controller as? any UIViewController & Responder,
                            completion: {
                                completion?(controller, true)
                            }
                        )
                    } else {
                        if let fallback {
                            navigate(
                                to: fallback.destination,
                                strategy: fallback.strategy,
                                animated: fallback.animated,
                                fallback: fallback.fallback,
                                event: event,
                                chainContext: chainContext,
                                completion: completion
                            )
                        } else {
                            completion?(nil, false)
                        }
                    }
                }
            )
        case let strategy as PopToExistingNavigationStrategy:
            let includingTabs = strategy.includingTabs

            func completePopFailure() {
                if let fallback {
                    navigate(
                        to: fallback.destination,
                        strategy: fallback.strategy,
                        animated: fallback.animated,
                        fallback: fallback.fallback,
                        event: event,
                        chainContext: chainContext,
                        completion: completion
                    )
                } else {
                    completion?(nil, false)
                }
            }

            func findController() -> UIViewController? {
                var sourceController = window?.topController
                var searchedContainers = Set<ObjectIdentifier>()
                while let source = sourceController {
                    let container =
                        includingTabs
                        ? source.orTabBarController ?? source.orNavigationController
                        : source.orNavigationController
                    if let container,
                        searchedContainers.insert(ObjectIdentifier(container)).inserted,
                        let controller = container.findController(destination: destination)
                    {
                        return controller
                    }
                    sourceController = presentingController(above: source)
                }

                return nil
            }

            func presentingController(above controller: UIViewController) -> UIViewController? {
                var current: UIViewController? = controller
                var searchedControllers = Set<ObjectIdentifier>()
                while let candidate = current,
                    searchedControllers.insert(ObjectIdentifier(candidate)).inserted
                {
                    if let presentingViewController = candidate.presentingViewController {
                        return presentingViewController
                    }
                    current = candidate.parent
                }

                return nil
            }

            if let controller = findController() {
                navigatorEvent = ResponderPoppedToExistingEvent()
                selectTabIfNeeded(
                    controller: controller,
                    completion: { [self] in
                        closeNavigationPresentedResult(
                            controller: controller,
                            animated: animated,
                            completion: { isSuccess in
                                guard isSuccess else {
                                    completePopFailure()

                                    return
                                }

                                perform(
                                    event: event,
                                    navigatorEvent: navigatorEvent,
                                    on: controller as? any UIViewController & Responder,
                                    completion: {
                                        completion?(controller, true)
                                    }
                                )
                            }
                        )
                    }
                )
            } else {
                completePopFailure()
            }
        case _ as ReplaceNavigationRootNavigationStrategy:
            if let navigationController = window?.topController?.orNavigationController {
                let controller = getController(destination: destination)
                guard navigationController.canSetNavigationRoot(controller) else {
                    if let fallback {
                        navigate(
                            to: fallback.destination,
                            strategy: fallback.strategy,
                            animated: fallback.animated,
                            fallback: fallback.fallback,
                            event: event,
                            chainContext: chainContext,
                            completion: completion
                        )
                    } else {
                        completion?(nil, false)
                    }

                    return
                }

                navigationController.setViewControllers(
                    [controller],
                    animated: animated,
                    completion: {
                        guard navigationController.viewControllers.count == 1,
                            navigationController.topViewController === controller
                        else {
                            if let fallback {
                                self.navigate(
                                    to: fallback.destination,
                                    strategy: fallback.strategy,
                                    animated: fallback.animated,
                                    fallback: fallback.fallback,
                                    event: event,
                                    chainContext: chainContext,
                                    completion: completion
                                )
                            } else {
                                completion?(nil, false)
                            }

                            return
                        }

                        perform(
                            event: event,
                            navigatorEvent: navigatorEvent,
                            on: controller as? any UIViewController & Responder,
                            completion: {
                                completion?(controller, true)
                            }
                        )
                    }
                )
            } else if let fallback {
                navigate(
                    to: fallback.destination,
                    strategy: fallback.strategy,
                    animated: fallback.animated,
                    fallback: fallback.fallback,
                    event: event,
                    chainContext: chainContext,
                    completion: completion
                )
            } else {
                completion?(nil, false)
            }
        case let strategy as PopoverNavigationStrategy:
            func completePopoverFailure() {
                if let fallback {
                    navigate(
                        to: fallback.destination,
                        strategy: fallback.strategy,
                        animated: fallback.animated,
                        fallback: fallback.fallback,
                        event: event,
                        chainContext: chainContext,
                        completion: completion
                    )
                } else {
                    completion?(nil, false)
                }
            }

            if let sourceController = window?.topController,
                sourceController.viewIfLoaded?.window != nil || sourceController === window?.rootViewController
            {
                let controller = getController(destination: destination)
                guard controller !== sourceController,
                    controller.parent == nil,
                    controller.presentingViewController == nil,
                    controller.presentedViewController == nil,
                    controller.transitionCoordinator == nil,
                    controller.viewIfLoaded?.window == nil,
                    controller.findController(controller: sourceController, withPresented: true) == nil,
                    sourceController.presentedViewController == nil,
                    !sourceController.isBeingDismissed,
                    !sourceController.isBeingPresented
                else {
                    completePopoverFailure()

                    return
                }

                controller.modalPresentationStyle = .popover
                if let popover = controller.popoverPresentationController {
                    strategy.configure(popover, controller)
                    let hasPopoverAnchor: Bool
                    if #available(iOS 16.0, *) {
                        hasPopoverAnchor = popover.sourceItem != nil
                            || popover.sourceView != nil
                            || popover.barButtonItem != nil
                    } else {
                        hasPopoverAnchor = popover.sourceView != nil || popover.barButtonItem != nil
                    }
                    guard hasPopoverAnchor else {
                        completePopoverFailure()

                        return
                    }
                    if popover.delegate == nil {
                        popover.delegate = popoverDelegate
                    }
                    sourceController.present(
                        controller,
                        animated: animated,
                        completion: {
                            let isPresented =
                                controller.presentingViewController != nil
                                || sourceController.presentedViewController === controller
                            guard isPresented else {
                                completePopoverFailure()

                                return
                            }

                            perform(
                                event: event,
                                navigatorEvent: navigatorEvent,
                                on: controller as? any UIViewController & Responder,
                                completion: {
                                    completion?(controller, true)
                                }
                            )
                        }
                    )
                } else {
                    completePopoverFailure()
                }
            } else {
                completePopoverFailure()
            }
        default:
            switch strategy {
            case let strategy as SplitNavigationStrategy:
                let splitController =
                    window?.topController?.orSplitViewController
                    ?? window?.rootViewController?.orSplitViewController
                let column: UISplitViewController.Column
                let action: SplitStrategy.SplitAction
                switch strategy.strategy {
                case let .primary(splitAction):
                    column = .primary
                    action = splitAction
                case let .secondary(splitAction):
                    column = .secondary
                    action = splitAction
                }

                func completeSplitFailure() {
                    if let fallback {
                        navigate(
                            to: fallback.destination,
                            strategy: fallback.strategy,
                            animated: fallback.animated,
                            fallback: fallback.fallback,
                            event: event,
                            chainContext: chainContext,
                            completion: completion
                        )
                    } else {
                        completion?(nil, false)
                    }
                }

                guard let splitController,
                    let initialNavigationController = splitController.columnNavigationController(for: column)
                else {
                    completeSplitFailure()

                    return
                }

                switch action {
                case .replace:
                    let controller = getController(destination: destination)
                    guard initialNavigationController.canSetNavigationRoot(controller) else {
                        completeSplitFailure()

                        return
                    }

                    splitController.showNavigatorColumn(column) {
                        guard let navigationController = splitController.columnNavigationController(for: column) else {
                            completeSplitFailure()

                            return
                        }

                        guard navigationController.canSetNavigationRoot(controller) else {
                            completeSplitFailure()

                            return
                        }

                        navigationController.setViewControllers(
                            [controller],
                            animated: animated,
                            completion: {
                                guard navigationController.viewControllers.count == 1,
                                    navigationController.topViewController === controller
                                else {
                                    completeSplitFailure()

                                    return
                                }

                                perform(
                                    event: event,
                                    navigatorEvent: navigatorEvent,
                                    on: controller as? any UIViewController & Responder,
                                    completion: {
                                        completion?(controller, true)
                                    }
                                )
                            }
                        )
                    }
                case .pop:
                    guard initialNavigationController.findController(destination: destination) != nil else {
                        completeSplitFailure()

                        return
                    }

                    splitController.showNavigatorColumn(column) {
                        guard let navigationController = splitController.columnNavigationController(for: column),
                            let controller = navigationController.findController(destination: destination)
                        else {
                            completeSplitFailure()

                            return
                        }

                        navigatorEvent = ResponderPoppedToExistingEvent()
                        self.closeNavigationPresentedResult(
                            controller: controller,
                            animated: animated,
                            completion: { isSuccess in
                                guard isSuccess else {
                                    completeSplitFailure()

                                    return
                                }

                                perform(
                                    event: event,
                                    navigatorEvent: navigatorEvent,
                                    on: controller as? any UIViewController & Responder,
                                    completion: {
                                        completion?(controller, true)
                                    }
                                )
                            }
                        )
                    }
                case .push:
                    let controller = self.getController(destination: destination)
                    guard initialNavigationController.canPushViewController(controller) else {
                        completeSplitFailure()

                        return
                    }

                    splitController.showNavigatorColumn(column) {
                        guard let navigationController = splitController.columnNavigationController(for: column) else {
                            completeSplitFailure()

                            return
                        }

                        self.push(
                            controller: controller,
                            to: navigationController,
                            animated: animated,
                            navigation: nil,
                            completion: { isSuccess in
                                let isCurrentColumnTop = splitController
                                    .columnNavigationController(for: column)?
                                    .topViewController === controller
                                guard isSuccess || isCurrentColumnTop else {
                                    completeSplitFailure()

                                    return
                                }

                                perform(
                                    event: event,
                                    navigatorEvent: navigatorEvent,
                                    on: controller as? any UIViewController & Responder,
                                    completion: {
                                        completion?(controller, true)
                                    }
                                )
                            }
                        )
                    }
                }
            default:
                completion?(nil, false)
            }
        }
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
        dismissPresented(
            in: sourceController,
            animated: animated,
            completion: { [self] in
                if let navigationController = window?.topController?.orNavigationController {
                    push(
                        controller: controller,
                        to: navigationController,
                        animated: animated,
                        navigation: navigation,
                        completion: completion
                    )
                } else {
                    completion?(false)
                }
            }
        )
    }

    private func push(
        controller: UIViewController,
        to navigationController: UINavigationController,
        animated: Bool,
        navigation: ((UINavigationController) -> Void)?,
        completion: ((Bool) -> Void)?
    ) {
        navigation?(navigationController)
        guard navigationController.canPushViewController(controller) else {
            completion?(false)

            return
        }

        navigationController.pushViewController(
            controller,
            animated: animated,
            completion: {
                completion?(
                    navigationController.topViewController === controller
                        && navigationController.viewControllers.contains(where: { $0 === controller })
                )
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
        closeNavigationPresentedResult(
            controller: controller,
            animated: animated,
            completion: { _ in completion?() }
        )
    }

    private func closeNavigationPresentedResult(
        controller: UIViewController?,
        animated: Bool,
        completion: @escaping (Bool) -> Void
    ) {
        guard let controller else {
            completion(false)

            return
        }

        dismissPresented(
            in: controller,
            animated: animated,
            completion: {
                guard let navigationController = controller.orNavigationController else {
                    completion(true)

                    return
                }

                if controller === navigationController {
                    completion(true)

                    return
                }

                let popTarget = navigationController.viewControllers.first {
                    $0 === controller || $0.findController(controller: controller, withPresented: false) != nil
                }
                guard let popTarget else {
                    completion(false)

                    return
                }

                navigationController.popToViewController(
                    popTarget,
                    animated: animated,
                    resultCompletion: completion
                )
            }
        )
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
        if let presentedViewController = controller?.presentedViewController {
            presentedViewController.dismiss(
                animated: animated,
                completion: { [self] in
                    if controller?.presentedViewController != nil {
                        dismissPresented(
                            in: controller,
                            animated: animated,
                            completion: completion
                        )
                    } else {
                        completion?()
                    }
                }
            )
        } else {
            completion?()
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
        strategy: NavigationStrategy,
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

    private func checkQueue() {
        guard !isQueueCheckSuspended, !isQueueCheckInProgress else { return }

        isQueueCheckInProgress = true
        defer { isQueueCheckInProgress = false }
        while !isQueueCheckSuspended,
            !(isNavigationInProgress || isChainNavigationInProgress),
            let queued = navigationQueue.dequeue()
        {
            enqueueOrStartNavigationChain(
                chain: queued.chain,
                event: queued.event,
                initialResult: queued.initialResult,
                completion: queued.completion
            )
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

}

private struct QueuedNavigation {
    let chain: [NavigationChainLink]
    let event: (any ResponderEvent)?
    let completion: ((UIViewController?, Bool) -> Void)?
    let initialResult: (UIViewController?, Bool)?
}

private struct NavigationChainContext {
    let remainingLinks: ArraySlice<NavigationChainLink>
    let completion: ((UIViewController?, Bool) -> Void)?
}

private final class NavigationOperation {}
