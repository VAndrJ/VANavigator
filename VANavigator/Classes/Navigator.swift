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
    public let screenFactory: NavigatorScreenFactory
    public var navigationInterceptor: NavigationInterceptor?

    public private(set) weak var window: UIWindow?

    private let navigationQueue = Queue<InterceptionDetail>()
    private var isNavigationInProgress = false {
        didSet { checkQueue() }
    }
    private var isChainNavigationInProgress = false {
        didSet { checkQueue() }
    }
    private let popoverDelegate = PopoverDelegate()

    public init(
        window: UIWindow?,
        screenFactory: NavigatorScreenFactory,
        navigationInterceptor: NavigationInterceptor? = nil
    ) {
        self.window = window
        self.screenFactory = screenFactory
        self.navigationInterceptor = navigationInterceptor

        bind()
    }

    /// Navigates through a chain of destinations.
    ///
    /// - Parameters:
    ///   - chain: An array of navigation links representing the navigation chain with destination and strategy.
    ///   - event: `ResponderEvent` to be handled by the destination controller.
    ///   - completion: A closure to be executed after the navigation is complete. Contains responder and navigation result.
    public func navigate(
        chain: [NavigationChainLink],
        event: ResponderEvent? = nil,
        linkCompletionResult: (UIViewController?, Bool)? = nil,
        completion: ((UIViewController?, Bool) -> Void)? = nil
    ) {
        guard !(isChainNavigationInProgress && linkCompletionResult == nil || isNavigationInProgress) else {
            navigationQueue.enqueue(InterceptionDetail(
                chain: chain,
                event: event,
                completion: completion
            ))

            return
        }

        isChainNavigationInProgress = true
        guard !chain.isEmpty else {
            isChainNavigationInProgress = false
            completion?(linkCompletionResult?.0, linkCompletionResult?.1 ?? false)

            return
        }

        var chain = chain
        let link = chain.removeFirst()
        if let navigationInterceptor, let interceptionResult = navigationInterceptor.intercept(destination: link.destination) {
            let chain = CollectionOfOne(link) + chain
            let detail = InterceptionDetail(
                chain: chain,
                event: event
            )
            navigationInterceptor.interceptionData[interceptionResult.reason] = detail
            isChainNavigationInProgress = false
            navigate(
                chain: interceptionResult.chain,
                event: interceptionResult.event,
                completion: completion
            )

            return
        }

        navigate(
            to: link.destination,
            strategy: link.strategy,
            animated: link.animated,
            fallback: link.fallback,
            event: event,
            completion: { [weak self] controller, result in
                DispatchQueue.main.async {
                    self?.navigate(
                        chain: chain,
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
    ///   - completion: A closure to be executed after the navigation is complete. Contains responder and navigation result.
    public func navigate(
        destination: NavigationDestination,
        strategy: NavigationStrategy,
        animated: Bool = true,
        fallbackStrategies: [NavigationStrategy],
        event: ResponderEvent? = nil,
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
        event: ResponderEvent? = nil,
        completion: ((UIViewController?, Bool) -> Void)? = nil
    ) {
        guard !(isChainNavigationInProgress || isNavigationInProgress) else {
            navigationQueue.enqueue(InterceptionDetail(
                chain: [
                    NavigationChainLink(
                        destination: destination,
                        strategy: strategy,
                        animated: animated,
                        fallback: fallback
                    ),
                ],
                event: event,
                completion: completion
            ))

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
                self?.isNavigationInProgress = false
                completion?(controller, result)
            }
        )
    }

    // swiftlint:disable function_body_length cyclomatic_complexity
    private func navigate(
        to destination: NavigationDestination,
        strategy: NavigationStrategy,
        animated: Bool,
        fallback: NavigationChainLink?,
        event: ResponderEvent?,
        completion: ((UIViewController?, Bool) -> Void)?
    ) {
        if let navigationInterceptor, let interceptionResult = navigationInterceptor.intercept(destination: destination) {
            let detail = InterceptionDetail(
                chain: [
                    NavigationChainLink(
                        destination: destination,
                        strategy: strategy,
                        animated: animated,
                        fallback: fallback
                    ),
                ],
                event: event
            )
            navigationInterceptor.interceptionData[interceptionResult.reason] = detail
            isNavigationInProgress = false
            navigate(
                chain: interceptionResult.chain,
                event: interceptionResult.event,
                completion: completion
            )

            return
        }

        var navigatorEvent: ResponderEvent?

        func perform(event: ResponderEvent?, navigatorEvent: ResponderEvent?, on responder: Responder?) {
            guard let responder else { return }

            if let navigatorEvent {
                Task {
                    await responder.handle(event: navigatorEvent)
                }
            }
            if let event {
                Task {
                    await responder.handle(event: event)
                }
            }
        }

        switch strategy {
        case _ as RemoveFromStackNavigationStrategy:
            if let navigationController = window?.topController?.orNavigationController {
                if navigationController.topViewController?.navigationIdentity?.isEqual(to: destination.identity) == true {
                    navigate(
                        to: destination,
                        strategy: .closeIfTop(),
                        animated: animated,
                        fallback: fallback,
                        event: event,
                        completion: completion
                    )
                } else if let index = navigationController.viewControllers.firstIndex(where: { $0.navigationIdentity?.isEqual(to: destination.identity) == true }) {
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
            if let controller = window?.topController {
                if tryToPop,
                   let navigationController = controller.orNavigationController,
                   navigationController.topViewController?.navigationIdentity?.isEqual(to: destination.identity) == true {
                    strategy.navigation?(navigationController)
                    navigationController.popViewController(
                        animated: animated,
                        completion: { [weak self] isSuccess in
                            guard let self else { return }

                            if !isSuccess, let fallback {
                                self.navigate(
                                    to: fallback.destination,
                                    strategy: fallback.strategy,
                                    animated: fallback.animated,
                                    fallback: fallback.fallback,
                                    event: event,
                                    completion: completion
                                )
                            } else {
                                completion?(nil, isSuccess)
                            }
                        }
                    )
                } else {
                    if tryToDismiss {
                        controller.dismiss(
                            animated: animated,
                            completion: {
                                completion?(nil, true)
                            }
                        )
                    } else {
                        completion?(nil, false)
                    }
                }
            } else {
                completion?(nil, false)
            }
        case let strategy as ReplaceWindowRootNavigationStrategy:
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
                        on: controller as? UIViewController & Responder
                    )
                    completion?(controller, true)
                }
            )
        case let strategy as PresentNavigationStrategy:
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
                if let sourceController {
                    let controller = getController(destination: destination)
                    sourceController.present(
                        controller,
                        animated: animated,
                        completion: {
                            perform(
                                event: event,
                                navigatorEvent: navigatorEvent,
                                on: controller as? UIViewController & Responder
                            )
                            completion?(controller, true)
                        }
                    )
                } else {
                    completion?(nil, false)
                }
            } else {
                completion?(nil, false)
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
                                    on: controller as? UIViewController & Responder
                                )
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
        case let strategy as PushNavigationStrategy:
            let controller = getController(destination: destination)
            let sourceController = controller.topController.orNavigationController
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
                            on: controller as? UIViewController & Responder
                        )
                        completion?(controller, true)
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

                return includingTabs ?
                (topController?.orTabBarController ?? topController?.orNavigationController)?.findController(destination: destination) :
                topController?.orNavigationController?.findController(destination: destination)
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
                                    on: controller as? UIViewController & Responder
                                )
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
                            on: controller as? UIViewController & Responder
                        )
                        completion?(controller, true)
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
            if let sourceController = window?.topController {
                let controller = getController(destination: destination)
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
                            perform(
                                event: event,
                                navigatorEvent: navigatorEvent,
                                on: controller as? UIViewController & Responder
                            )
                            completion?(controller, true)
                        }
                    )
                } else {
                    completion?(nil, false)
                }
            } else {
                completion?(nil, false)
            }
        default:
            switch strategy {
            case let strategy as SplitNavigationStrategy:
                let strategy = strategy.strategy
                // MARK: - Plain flow for easier understanding
                if let splitController = window?.topController?.splitViewController {
                    switch strategy {
                    case let .primary(action):
                        switch action {
                        case .replace:
                            if let navigationController = splitController.viewController(for: .primary)?.orNavigationController {
                                splitController.show(.primary)
                                let controller = getController(destination: destination)
                                navigationController.setViewControllers(
                                    [controller],
                                    animated: animated,
                                    completion: {
                                        perform(
                                            event: event,
                                            navigatorEvent: navigatorEvent,
                                            on: controller as? UIViewController & Responder
                                        )
                                        completion?(controller, true)
                                    }
                                )
                                // TODO: - fallback?
                            } else {
                                completion?(nil, false)
                            }
                        case .pop:
                            if let controller = splitController.viewController(for: .primary)?.orNavigationController?.findController(destination: destination) {
                                splitController.show(.primary)
                                navigatorEvent = ResponderPoppedToExistingEvent()
                                closeNavigationPresented(
                                    controller: controller,
                                    animated: animated,
                                    completion: {
                                        perform(
                                            event: event,
                                            navigatorEvent: navigatorEvent,
                                            on: controller as? UIViewController & Responder
                                        )
                                        completion?(controller, true)
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
                            if let navigationController = splitController.viewController(for: .primary)?.orNavigationController {
                                splitController.show(.primary)
                                let controller = getController(destination: destination)
                                navigationController.pushViewController(
                                    controller,
                                    animated: animated,
                                    completion: {
                                        perform(
                                            event: event,
                                            navigatorEvent: navigatorEvent,
                                            on: controller as? UIViewController & Responder
                                        )
                                        completion?(controller, true)
                                    }
                                )
                                // TODO: - fallback?
                            } else {
                                completion?(nil, false)
                            }
                        }
                    case let .secondary(action):
                        switch action {
                        case .replace:
                            if let navigationController = splitController.viewController(for: .secondary)?.orNavigationController {
                                splitController.show(.secondary)
                                let controller = getController(destination: destination)
                                navigationController.setViewControllers(
                                    [controller],
                                    animated: animated,
                                    completion: {
                                        perform(
                                            event: event,
                                            navigatorEvent: navigatorEvent,
                                            on: controller as? UIViewController & Responder
                                        )
                                        completion?(controller, true)
                                    }
                                )
                                // TODO: - fallback?
                            } else {
                                completion?(nil, false)
                            }
                        case .pop:
                            if let controller = splitController.viewController(for: .secondary)?.orNavigationController?.findController(destination: destination) {
                                splitController.show(.secondary)
                                navigatorEvent = ResponderPoppedToExistingEvent()
                                closeNavigationPresented(
                                    controller: controller,
                                    animated: animated,
                                    completion: {
                                        perform(
                                            event: event,
                                            navigatorEvent: navigatorEvent,
                                            on: controller as? UIViewController & Responder
                                        )
                                        completion?(controller, true)
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
                            if let navigationController = splitController.viewController(for: .secondary)?.orNavigationController {
                                splitController.show(.secondary)
                                let controller = getController(destination: destination)
                                navigationController.pushViewController(
                                    controller,
                                    animated: animated,
                                    completion: {
                                        perform(
                                            event: event,
                                            navigatorEvent: navigatorEvent,
                                            on: controller as? UIViewController & Responder
                                        )
                                        completion?(controller, true)
                                    }
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
    public func replaceWindowRoot(controller: UIViewController, transition: CATransition?, completion: (() -> Void)?) {
        if window?.rootViewController == nil {
            window?.rootViewController = controller
            window?.makeKeyAndVisible()
            completion?()
        } else {
            window?.set(
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
            dismissPresented(in: controller, animated: animated, completion: {
                if let navigationController = controller.orNavigationController {
                    navigationController.popToViewController(
                        controller,
                        animated: animated,
                        completion: completion
                    )
                } else {
                    completion?()
                }
            })
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
            presentedViewController.dismiss(animated: animated, completion: { [weak self] in
                if controller?.presentedViewController != nil {
                    self?.dismissPresented(
                        in: controller,
                        animated: animated,
                        completion: completion
                    )
                } else {
                    completion?()
                }
            })
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
            for index in (tabBarController.viewControllers ?? []).indices where tabBarController.viewControllers?[index].findController(controller: controller, withPresented: false) != nil {
                if tabBarController.selectedIndex != index {
                    tabBarController.selectedIndex = index
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        completion?()
                    }
                } else {
                    completion?()
                }
                
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
        guard !(isNavigationInProgress || isChainNavigationInProgress) else { return }
        guard let queued = navigationQueue.dequeue() else { return }

        navigate(
            chain: queued.chain,
            event: queued.event,
            completion: queued.completion
        )
    }

    private func bind() {
        navigationInterceptor?.onInterceptionResolved = { [weak self] reason, newStrategy, prefixNavigationChain, suffixNavigationChain, completion in
            guard let self else { return }

            if let data = self.navigationInterceptor?.interceptionData.removeValue(forKey: reason) {
                if let newStrategy, !data.chain.isEmpty {
                    data.chain[0].update(strategy: newStrategy)
                }

                self.navigate(
                    chain: prefixNavigationChain + data.chain + suffixNavigationChain,
                    event: data.event,
                    completion: completion
                )
            }
        }
    }
}
// swiftlint:enable file_length type_body_length
