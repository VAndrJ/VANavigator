//
//  Navigator.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

@MainActor // Default isolation issue workaround.
open class Navigator {
    public let screenFactory: any NavigatorScreenFactory
    public var navigationInterceptor: NavigationInterceptor? {
        didSet {
            guard oldValue !== navigationInterceptor else { return }

            oldValue?.removeNavigations(for: self)
        }
    }

    public private(set) weak var window: UIWindow?

    private var navigationQueue = Queue<QueuedNavigation>()
    private var isNavigationInProgress = false {
        didSet { checkQueue() }
    }
    private var isChainNavigationInProgress = false {
        didSet { checkQueue() }
    }
    private var isQueueCheckSuspended = false
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

    #if VANAVIGATOR_DEINIT_WORKAROUND
    // Workaround swiftlang/swift#85663 when XCTest releases an isolated object.
    nonisolated deinit {
        guard Thread.isMainThread else { return }

        MainActor.assumeIsolated {
            let actorIsolatedStorage = (
                screenFactory,
                navigationInterceptor,
                navigationQueue,
                popoverDelegate
            )
            Task { @MainActor in
                withExtendedLifetime(actorIsolatedStorage) {}
            }

            navigationInterceptor?.removeNavigations(for: self)
        }
    }
    #else
    isolated deinit {
        navigationInterceptor?.removeNavigations(for: self)
    }
    #endif

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
            event: event,
            linkCompletionResult: initialResult,
            completion: completion
        )
    }

    private func continueNavigationChain(
        chain: [NavigationChainLink],
        event: (any ResponderEvent)?,
        linkCompletionResult: (UIViewController?, Bool)?,
        completion: ((UIViewController?, Bool) -> Void)?
    ) {
        guard !chain.isEmpty else {
            completion?(linkCompletionResult?.0, linkCompletionResult?.1 ?? false)
            isChainNavigationInProgress = false

            return
        }

        var chain = chain
        let link = chain.removeFirst()
        if let navigationInterceptor,
            let interceptionResult = navigationInterceptor.intercept(
                destination: link.destination
            )
        {
            let chain = CollectionOfOne(link) + chain
            let detail = InterceptedNavigation(
                chain: chain,
                event: event,
                navigator: self
            )
            navigationInterceptor.store(detail, reason: interceptionResult.reason)
            performSuspendingQueueCheck {
                isChainNavigationInProgress = false
                navigate(
                    chain: interceptionResult.chain,
                    event: interceptionResult.event,
                    completion: completion
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
            completion: { [weak self] controller, result in
                guard let self else { return }
                guard result else {
                    completion?(controller, false)
                    self.isChainNavigationInProgress = false

                    return
                }

                self.continueNavigationChain(
                    chain: chain,
                    event: event,
                    linkCompletionResult: (controller, result),
                    completion: completion
                )
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

        isNavigationInProgress = true
        navigate(
            to: destination,
            strategy: strategy,
            animated: animated,
            fallback: fallback,
            event: event,
            completion: { [weak self] controller, result in
                completion?(controller, result)
                self?.isNavigationInProgress = false
            }
        )
    }

    private func navigate(
        to destination: NavigationDestination,
        strategy: NavigationStrategy,
        animated: Bool,
        fallback: NavigationChainLink?,
        event: (any ResponderEvent)?,
        completion: ((UIViewController?, Bool) -> Void)?
    ) {
        if let navigationInterceptor,
            let interceptionResult = navigationInterceptor.intercept(
                destination: destination
            )
        {
            let detail = InterceptedNavigation(
                chain: [
                    NavigationChainLink(
                        destination: destination,
                        strategy: strategy,
                        animated: animated,
                        fallback: fallback
                    )
                ],
                event: event,
                navigator: self
            )
            navigationInterceptor.store(detail, reason: interceptionResult.reason)
            performSuspendingQueueCheck {
                isNavigationInProgress = false
                navigate(
                    chain: interceptionResult.chain,
                    event: interceptionResult.event,
                    completion: completion
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

            Task {
                if let navigatorEvent {
                    _ = await responder.handle(event: navigatorEvent)
                }
                if let event {
                    _ = await responder.handle(event: event)
                }
                completion()
            }
        }

        switch strategy {
        case _ as RemoveFromStackNavigationStrategy:
            if let navigationController = window?.topController?.orNavigationController {
                if navigationController.topViewController.map({
                    destination.isEqual(to: .controller($0))
                }) == true {
                    navigate(
                        to: destination,
                        strategy: .closeIfTop(),
                        animated: animated,
                        fallback: fallback,
                        event: event,
                        completion: completion
                    )
                } else if let index = navigationController.viewControllers.firstIndex(
                    where: { destination.isEqual(to: .controller($0)) }
                ) {
                    navigationController.viewControllers.remove(at: index)

                    completion?(nil, true)
                } else {
                    completion?(nil, false)
                }
            } else if let fallback {
                navigate(
                    to: fallback.destination,
                    strategy: fallback.strategy,
                    animated: fallback.animated,
                    fallback: fallback.fallback,
                    event: event,
                    completion: completion
                )
            } else {
                completion?(nil, false)
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
                        completion: completion
                    )
                } else {
                    completion?(nil, false)
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
                                completion?(nil, true)
                            } else if tryToDismiss, let presentedController = presentedContainer(for: controller) {
                                presentedController.dismiss(
                                    animated: animated,
                                    completion: {
                                        completion?(nil, true)
                                    }
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
                            completion: {
                                completion?(nil, true)
                            }
                        )
                    } else {
                        completeCloseFailure()
                    }
                }
            } else {
                completeCloseFailure()
            }
        case let strategy as ReplaceWindowRootNavigationStrategy:
            guard window != nil else {
                if let fallback {
                    navigate(
                        to: fallback.destination,
                        strategy: fallback.strategy,
                        animated: fallback.animated,
                        fallback: fallback.fallback,
                        event: event,
                        completion: completion
                    )
                } else {
                    completion?(nil, false)
                }

                return
            }

            let transition = animated ? strategy.transition : nil
            let controller = getController(destination: destination)
            if window?.rootViewController != nil {
                navigatorEvent = ResponderReplacedWindowRootControllerEvent()
            }
            replaceWindowRoot(
                controller: controller,
                transition: transition,
                completion: {
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
        case let strategy as PresentNavigationStrategy:
            func completePresentationFailure() {
                if let fallback {
                    navigate(
                        to: fallback.destination,
                        strategy: fallback.strategy,
                        animated: fallback.animated,
                        fallback: fallback.fallback,
                        event: event,
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
                    completion: { [weak self] in
                        guard let self else { return }

                        self.closeNavigationPresentedResult(
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
                completion: { [weak self] isSuccess in
                    guard let self else { return }

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
                            self.navigate(
                                to: fallback.destination,
                                strategy: fallback.strategy,
                                animated: fallback.animated,
                                fallback: fallback.fallback,
                                event: event,
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
                    sourceController = source.presentingViewController
                }

                return nil
            }

            if let controller = findController() {
                navigatorEvent = ResponderPoppedToExistingEvent()
                selectTabIfNeeded(
                    controller: controller,
                    completion: { [weak self] in
                        guard let self else { return }

                        self.closeNavigationPresentedResult(
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
            completion: { [weak self] in
                guard let self else { return }

                if let navigationController = self.window?.topController?.orNavigationController {
                    self.push(
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
    public func replaceWindowRoot(
        controller: UIViewController,
        transition: CATransition?,
        completion: (() -> Void)?
    ) {
        guard let window else {
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
                completion: { [weak self] in
                    if controller?.presentedViewController != nil {
                        self?.dismissPresented(
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
        if let controller, let tabBarController = controller.findTabBarController() {
            for index in (tabBarController.viewControllers ?? []).indices
            where tabBarController.viewControllers?[index].findController(
                controller: controller,
                withPresented: false
            ) != nil {
                if tabBarController.selectedIndex != index {
                    tabBarController.selectedIndex = index
                }
                completion?()

                return
            }
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
        guard !isQueueCheckSuspended else { return }
        guard !(isNavigationInProgress || isChainNavigationInProgress) else { return }
        guard let queued = navigationQueue.dequeue() else { return }

        enqueueOrStartNavigationChain(
            chain: queued.chain,
            event: queued.event,
            initialResult: queued.initialResult,
            completion: queued.completion
        )
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
