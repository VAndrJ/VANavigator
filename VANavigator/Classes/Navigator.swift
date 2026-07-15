//
//  Navigator.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

// swiftlint:disable file_length type_body_length
@MainActor
open class Navigator {
    public let screenFactory: any NavigatorScreenFactory
    public var navigationInterceptor: NavigationInterceptor?

    public private(set) weak var window: UIWindow?

    private let navigationQueue = Queue<QueuedNavigation>()
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

    /// Navigates through a chain of destinations.
    ///
    /// - Parameters:
    ///   - chain: An array of navigation links representing the navigation chain with destination and strategy.
    ///   - event: `ResponderEvent` to be handled by the destination controller.
    ///   - completion: A closure to be executed after the navigation is complete. Contains responder and navigation result.
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
        if let navigationInterceptor, let interceptionResult = navigationInterceptor.intercept(destination: link.destination) {
            let chain = CollectionOfOne(link) + chain
            let detail = InterceptedNavigation(
                chain: chain,
                event: event,
                navigator: self
            )
            navigationInterceptor.interceptionData[interceptionResult.reason, default: []].append(detail)
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
                self?.continueNavigationChain(
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
    ///   - completion: A closure to be executed after the navigation is complete. Contains responder and navigation result.
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
    ///   - completion: A closure to be executed after the navigation is complete. Contains responder and navigation result.
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

    // swiftlint:disable function_body_length cyclomatic_complexity
    private func navigate(
        to destination: NavigationDestination,
        strategy: NavigationStrategy,
        animated: Bool,
        fallback: NavigationChainLink?,
        event: (any ResponderEvent)?,
        completion: ((UIViewController?, Bool) -> Void)?
    ) {
        if let navigationInterceptor, let interceptionResult = navigationInterceptor.intercept(destination: destination) {
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
            navigationInterceptor.interceptionData[interceptionResult.reason, default: []].append(detail)
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
            completion: @MainActor @escaping () -> Void
        ) {
            guard let responder, navigatorEvent != nil || event != nil else {
                completion()

                return
            }

            Task { @MainActor in
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

            let transition = strategy.transition
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
                            let isPresented = controller.presentingViewController != nil
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
            if let controller = window?.findController(destination: destination) {
                navigatorEvent = ResponderClosedToExistingEvent()
                selectTabIfNeeded(
                    controller: controller,
                    completion: { [weak self] in
                        guard let self else { return }

                        self.closeNavigationPresented(
                            controller: controller,
                            animated: animated,
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

            func findController() -> UIViewController? {
                let topController = window?.topController

                return includingTabs
                    ? (topController?.orTabBarController ?? topController?.orNavigationController)?.findController(destination: destination)
                    : topController?.orNavigationController?.findController(destination: destination)
            }

            if let controller = findController() {
                navigatorEvent = ResponderPoppedToExistingEvent()
                selectTabIfNeeded(
                    controller: controller,
                    completion: { [weak self] in
                        guard let self else { return }

                        self.closeNavigationPresented(
                            controller: controller,
                            animated: animated,
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
        case _ as ReplaceNavigationRootNavigationStrategy:
            if let navigationController = window?.topController?.orNavigationController {
                let controller = getController(destination: destination)
                navigationController.setViewControllers(
                    [controller],
                    animated: animated,
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
                            let isPresented = controller.presentingViewController != nil
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
                let strategy = strategy.strategy
                // MARK: - Plain flow for easier understanding
                let splitController = window?.topController?.orSplitViewController
                    ?? window?.rootViewController?.orSplitViewController
                if let splitController {
                    switch strategy {
                    case let .primary(action):
                        switch action {
                        case .replace:
                            if let navigationController = splitController.columnNavigationController(for: .primary) {
                                splitController.show(.primary)
                                let controller = getController(destination: destination)
                                navigationController.setViewControllers(
                                    [controller],
                                    animated: animated,
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
                        case .pop:
                            if let controller = splitController.columnNavigationController(for: .primary)?.findController(destination: destination)
                            {
                                splitController.show(.primary)
                                navigatorEvent = ResponderPoppedToExistingEvent()
                                closeNavigationPresented(
                                    controller: controller,
                                    animated: animated,
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
                        case .push:
                            if let navigationController = splitController.columnNavigationController(for: .primary) {
                                splitController.show(.primary)
                                let controller = getController(destination: destination)
                                navigationController.pushViewController(
                                    controller,
                                    animated: animated,
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
                        }
                    case let .secondary(action):
                        switch action {
                        case .replace:
                            if let navigationController = splitController.columnNavigationController(for: .secondary) {
                                splitController.show(.secondary)
                                let controller = getController(destination: destination)
                                navigationController.setViewControllers(
                                    [controller],
                                    animated: animated,
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
                        case .pop:
                            if let controller = splitController.columnNavigationController(for: .secondary)?.findController(
                                destination: destination
                            ) {
                                splitController.show(.secondary)
                                navigatorEvent = ResponderPoppedToExistingEvent()
                                closeNavigationPresented(
                                    controller: controller,
                                    animated: animated,
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
                        case .push:
                            if let navigationController = splitController.columnNavigationController(for: .secondary) {
                                splitController.show(.secondary)
                                let controller = getController(destination: destination)
                                navigationController.pushViewController(
                                    controller,
                                    animated: animated,
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
                        }
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
            default:
                completion?(nil, false)
            }
        }
    }
    // swiftlint:enable function_body_length cyclomatic_complexity

    /// Retrieves a view controller based on the provided navigation destination.
    ///
    /// - Parameter destination: The navigation destination indicating whether to assemble a screen using an identity or use an existing controller.
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

    /// Pushes a view controller onto the navigation stack of the top view controller in the window, dismissing presented controllers in the process.
    ///
    /// - Parameters:
    ///   - sourceController: The source controller from which presented controllers will be dismissed.
    ///   - controller: The view controller to push onto the navigation stack.
    ///   - animated: Should be animated or not.
    ///   - completion: A closure to be executed after the push is complete. `true` if successful, `false` if a navigation controller was not found.
    /// - Returns: A boolean value indicating whether the push operation was successful. `true` if successful, `false` if a navigation controller was not found.
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

                if !(controller is UINavigationController), let navigationController = self.window?.topController?.orNavigationController {
                    navigation?(navigationController)
                    navigationController.pushViewController(
                        controller,
                        animated: animated,
                        completion: {
                            completion?(true)
                        }
                    )
                } else {
                    completion?(false)
                }
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

    /// Dismisses all presented view controllers within the given controller while they are being presented and pops back to the specified controller in the navigation stack if it exists.
    ///
    /// - Parameters:
    ///   - controller: Controller with presented controllers to dismiss and the target for navigation stack pop.
    ///   - animated: Should be animated or not.
    ///   - completion: A closure to be executed after controllers are dismissed.
    public func closeNavigationPresented(controller: UIViewController?, animated: Bool, completion: (() -> Void)?) {
        if let controller {
            dismissPresented(
                in: controller,
                animated: animated,
                completion: {
                    if let navigationController = controller.orNavigationController {
                        navigationController.popToViewController(
                            controller,
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
            where tabBarController.viewControllers?[index].findController(controller: controller, withPresented: false) != nil {
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
// swiftlint:enable file_length type_body_length
