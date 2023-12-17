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
    public let screenFactory: NavigatorScreenFactory
    public var navigationInterceptor: NavigationInterceptor?

    public private(set) weak var window: UIWindow?

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
    @discardableResult
    public func navigate(
        chain: [NavigationChainLink],
        event: ResponderEvent? = nil,
        completion: (((UIViewController & Responder)?, Bool) -> Void)? = nil
    ) {
        guard !chain.isEmpty else {
            completion?(nil, false)

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
            navigate(
                chain: interceptionResult.chain,
                event: interceptionResult.event,
                completion: completion
            )

            return
        }

        navigate(
            destination: link.destination,
            strategy: link.strategy,
            animated: link.animated,
            fallback: link.fallback,
            event: event,
            completion: { [weak self] _, _ in
                DispatchQueue.main.async {
                    self?.navigate(
                        chain: chain,
                        event: event,
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
    ///   - fallback: The fallback navigation chain link.
    ///   - event: `ResponderEvent` to be handled by the destination controller.
    ///   - completion: A closure to be executed after the navigation is complete. Contains responder and navigation result.
    @discardableResult
    public func navigate(
        destination: NavigationDestination,
        strategy: NavigationStrategy,
        animated: Bool = true,
        fallback: NavigationChainLink? = nil,
        event: ResponderEvent? = nil,
        completion: (((UIViewController & Responder)?, Bool) -> Void)? = nil
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
            navigate(
                chain: interceptionResult.chain,
                event: interceptionResult.event,
                completion: completion
            )

            return
        }

        let eventController: (UIViewController & Responder)?
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
        case let .closeIfTop(tryToPop, tryToDismiss):
            if let controller = window?.topController {
                if tryToPop, controller.navigationController?.topViewController?.navigationIdentity?.isEqual(to: destination.identity) == true  {
                    controller.navigationController?.popViewController(
                        animated: animated,
                        completion: {
                            completion?(nil, true)
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
        case let .replaceWindowRoot(transition):
            let controller = getController(destination: destination)
            eventController = controller as? UIViewController & Responder
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
                        on: eventController
                    )
                    completion?(eventController, true)
                }
            )
        case .present:
            let controller = getController(destination: destination)
            eventController = controller as? UIViewController & Responder
            present(
                controller: controller,
                animated: animated,
                completion: {
                    perform(
                        event: event,
                        navigatorEvent: navigatorEvent,
                        on: eventController
                    )
                    completion?(eventController, true)
                }
            )
        case .closeToExistingOrPresent:
            if let controller = window?.findController(destination: destination) {
                eventController = controller as? UIViewController & Responder
                navigatorEvent = ResponderClosedToExistingEvent()
                selectTabIfNeeded(
                    controller: window?.topController,
                    completion: { [weak self] sourceController in
                        guard let self else { return }

                        closeNavigationPresented(
                            controller: sourceController ?? controller,
                            animated: animated,
                            completion: {
                                perform(
                                    event: event,
                                    navigatorEvent: navigatorEvent,
                                    on: eventController
                                )
                                completion?(eventController, true)
                            }
                        )
                    }
                )
            } else {
                navigate(
                    destination: destination,
                    strategy: .present,
                    animated: animated,
                    fallback: fallback,
                    event: event,
                    completion: completion
                )
            }
        case .push:
            let controller = getController(destination: destination)
            eventController = controller as? UIViewController & Responder
            selectTabIfNeeded(
                controller: window?.topController,
                completion: { [weak self] sourceController in
                    guard let self else { return }

                    let sourceController = sourceController?.topController.orNavigationController
                    push(
                        sourceController: sourceController,
                        controller: controller,
                        animated: animated,
                        completion: { [weak self] isSuccess in
                            guard let self else { return }

                            if isSuccess {
                                perform(
                                    event: event,
                                    navigatorEvent: navigatorEvent,
                                    on: eventController
                                )
                                completion?(eventController, true)
                            } else {
                                if let fallback {
                                    navigate(
                                        destination: fallback.destination,
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
                }
            )
        case let .popToExisting(includingTabs):
            func findController() -> UIViewController? {
                let topController = window?.topController

                return includingTabs ?
                topController?.orTabBarController?.findController(destination: destination) ?? topController?.orNavigationController?.findController(destination: destination) :
                topController?.orNavigationController?.findController(destination: destination)
            }

            if let controller = findController() {
                selectTabIfNeeded(controller: controller)
                eventController = controller as? UIViewController & Responder
                navigatorEvent = ResponderPoppedToExistingEvent()
                closeNavigationPresented(
                    controller: controller,
                    animated: animated,
                    completion: {
                        perform(
                            event: event,
                            navigatorEvent: navigatorEvent,
                            on: eventController
                        )
                        completion?(eventController, true)
                    }
                )
            } else if let fallback {
                navigate(
                    destination: fallback.destination,
                    strategy: fallback.strategy,
                    animated: fallback.animated,
                    fallback: fallback.fallback,
                    event: event,
                    completion: completion
                )
            } else {
                completion?(nil, false)
            }
        case .replaceNavigationRoot:
            if let navigationController = window?.topController?.navigationController {
                let controller = getController(destination: destination)
                eventController = controller as? UIViewController & Responder
                navigationController.setViewControllers(
                    [controller],
                    animated: animated,
                    completion: {
                        perform(event: event, navigatorEvent: navigatorEvent, on: eventController)
                        completion?(eventController, true)
                    }
                )
            } else if let fallback {
                navigate(
                    destination: fallback.destination,
                    strategy: fallback.strategy,
                    animated: fallback.animated,
                    fallback: fallback.fallback,
                    event: event,
                    completion: completion
                )
            } else {
                completion?(nil, false)
            }
        case let .showSplit(strategy):
            // MARK: - Plain flow for easier understanding
            if let splitController = window?.topController?.splitViewController {
                switch strategy {
                case .replacePrimary:
                    if #available(iOS 14.0, *) {
                        if splitController.isSingleNavigation {
                            return navigate(
                                destination: destination,
                                strategy: .replaceNavigationRoot,
                                animated: animated,
                                fallback: fallback,
                                event: event,
                                completion: completion
                            )
                        } else {
                            let controller = getController(destination: destination)
                            splitController.setViewController(controller, for: .primary)
                            eventController = controller as? UIViewController & Responder
                            perform(event: event, navigatorEvent: navigatorEvent, on: eventController)
                            completion?(eventController, true)
                        }
                    } else {
                        let controller = getController(destination: destination)
                        eventController = controller as? UIViewController & Responder
                        splitController.viewControllers = [controller]
                        perform(event: event, navigatorEvent: navigatorEvent, on: eventController)
                        completion?(eventController, true)
                    }
                case let .secondary(shouldPop):
                    if #available(iOS 14.0, *) {
                        if splitController.isSingleNavigation {
                            // TODO: -
                            navigate(
                                destination: destination,
                                strategy: shouldPop ? .popToExisting() : .push,
                                animated: animated,
                                fallback: fallback,
                                event: event,
                                completion: completion
                            )
                        } else {
                            if let navigationController = splitController.viewController(for: .secondary)?.navigationController,
                               shouldPop,
                               let controller = navigationController.findController(destination: destination) {
                                eventController = controller as? UIViewController & Responder
                                navigatorEvent = ResponderPoppedToExistingEvent()
                                dismissPresented(
                                    in: navigationController,
                                    animated: animated,
                                    completion: {
                                        navigationController.popToViewController(
                                            controller,
                                            animated: animated,
                                            completion: {
                                                perform(event: event, navigatorEvent: navigatorEvent, on: eventController)
                                                completion?(eventController, true)
                                            }
                                        )
                                    }
                                )
                            } else {
                                let controller = getController(destination: destination)
                                eventController = controller as? UIViewController & Responder
                                splitController.setViewController(controller, for: .secondary)
                                dismissPresented(
                                    in: splitController,
                                    animated: animated,
                                    completion: {
                                        perform(event: event, navigatorEvent: navigatorEvent, on: eventController)
                                        completion?(eventController, true)
                                    }
                                )
                            }
                        }
                    } else {
                        let controller = getController(destination: destination)
                        splitController.showDetailViewController(controller, sender: nil)
                        eventController = controller as? UIViewController & Responder
                        dismissPresented(
                            in: splitController,
                            animated: animated,
                            completion: {
                                perform(event: event, navigatorEvent: navigatorEvent, on: eventController)
                                completion?(eventController, true)
                            }
                        )
                    }
                case let .replaceSecondary(shouldPop):
                    if #available(iOS 14.0, *) {
                        if splitController.isSingleNavigation {
                            // TODO: -
                            navigate(
                                destination: destination,
                                strategy: shouldPop ? .popToExisting() : .push,
                                animated: animated,
                                fallback: fallback,
                                event: event,
                                completion: completion
                            )
                        } else {
                            if let navigationController = splitController.viewController(for: .secondary)?.navigationController {
                                if shouldPop, navigationController.viewControllers.first?.navigationIdentity?.isEqual(to: destination.identity) == true {
                                    eventController = navigationController.viewControllers.first as? UIViewController & Responder
                                    navigatorEvent = ResponderPoppedToExistingEvent()
                                    dismissPresented(
                                        in: navigationController,
                                        animated: animated,
                                        completion: {
                                            navigationController.popToRootViewController(
                                                animated: animated,
                                                completion: {
                                                    perform(event: event, navigatorEvent: navigatorEvent, on: eventController)
                                                    completion?(eventController, true)
                                                }
                                            )
                                        }
                                    )
                                } else {
                                    let controller = getController(destination: destination)
                                    eventController = controller as? UIViewController & Responder
                                    dismissPresented(
                                        in: navigationController,
                                        animated: animated,
                                        completion: {
                                            navigationController.setViewControllers(
                                                [controller],
                                                animated: animated,
                                                completion: {
                                                    perform(event: event, navigatorEvent: navigatorEvent, on: eventController)
                                                    completion?(eventController, true)
                                                }
                                            )
                                        }
                                    )
                                }
                            } else {
                                let controller = getController(destination: destination)
                                eventController = controller as? UIViewController & Responder
                                dismissPresented(
                                    in: splitController,
                                    animated: animated,
                                    completion: {
                                        splitController.setViewController(controller, for: .secondary)
                                        perform(event: event, navigatorEvent: navigatorEvent, on: eventController)
                                        completion?(eventController, true)
                                    }
                                )
                            }
                        }
                    } else {
                        let controller = getController(destination: destination)
                        eventController = controller as? UIViewController & Responder
                        dismissPresented(
                            in: splitController,
                            animated: animated,
                            completion: {
                                splitController.viewControllers = splitController.viewControllers.first.flatMap { [$0, controller] } ?? [controller]
                                perform(event: event, navigatorEvent: navigatorEvent, on: eventController)
                                completion?(eventController, true)
                            }
                        )
                    }
                case let .replaceSupplementary(shouldPop):
                    if #available(iOS 14.0, *) {
                        if splitController.isSingleNavigation {
                            // TODO: -
                            navigate(
                                destination: destination,
                                strategy: shouldPop ? .popToExisting() : .push,
                                animated: animated,
                                fallback: fallback,
                                event: event,
                                completion: completion
                            )
                        } else {
                            if splitController.style == .tripleColumn {
                                if let navigationController = splitController.viewController(for: .supplementary)?.navigationController {
                                    if shouldPop, navigationController.viewControllers.first?.navigationIdentity?.isEqual(to: destination.identity) == true {
                                        eventController = navigationController.viewControllers.first as? UIViewController & Responder
                                        navigatorEvent = ResponderPoppedToExistingEvent()
                                        dismissPresented(
                                            in: navigationController,
                                            animated: animated,
                                            completion: {
                                                navigationController.popToRootViewController(
                                                    animated: animated,
                                                    completion: {
                                                        perform(event: event, navigatorEvent: navigatorEvent, on: eventController)
                                                        completion?(eventController, true)
                                                    }
                                                )
                                            }
                                        )
                                    } else {
                                        let controller = getController(destination: destination)
                                        eventController = controller as? UIViewController & Responder
                                        dismissPresented(
                                            in: navigationController,
                                            animated: animated,
                                            completion: {
                                                navigationController.setViewControllers(
                                                    [controller],
                                                    animated: animated,
                                                    completion: {
                                                        perform(event: event, navigatorEvent: navigatorEvent, on: eventController)
                                                        completion?(eventController, true)
                                                    }
                                                )
                                            }
                                        )
                                    }
                                } else {
                                    let controller = getController(destination: destination)
                                    eventController = controller as? UIViewController & Responder
                                    dismissPresented(
                                        in: splitController,
                                        animated: animated,
                                        completion: {
                                            splitController.setViewController(controller, for: .supplementary)
                                            perform(event: event, navigatorEvent: navigatorEvent, on: eventController)
                                            completion?(eventController, true)
                                        }
                                    )
                                }
                            } else {
                                // TODO: -
                                navigate(
                                    destination: destination,
                                    strategy: .showSplit(strategy: .secondary(shouldPop: shouldPop)),
                                    animated: animated,
                                    fallback: fallback,
                                    event: event,
                                    completion: completion
                                )
                            }
                        }
                    } else {
                        let controller = getController(destination: destination)
                        eventController = controller as? UIViewController & Responder
                        dismissPresented(
                            in: splitController,
                            animated: animated,
                            completion: {
                                splitController.viewControllers = Array(splitController.viewControllers.prefix(2)) + [controller]
                                perform(event: event, navigatorEvent: navigatorEvent, on: eventController)
                                completion?(eventController, true)
                            }
                        )
                    }
                }
            } else {
                if let fallback {
                    navigate(
                        destination: fallback.destination,
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
    }

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
        completion: ((Bool) -> Void)?
    ) {
        dismissPresented(
            in: sourceController,
            animated: animated,
            completion: { [weak self] in
                guard let self else { return }

                if !(controller is UINavigationController), let navigationController = window?.topController?.orNavigationController {
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

    /// Presents a view controller from the current top controller in the window or sets it as the `rootViewController` if the window is empty.
    ///
    /// - Parameters:
    ///   - controller: The view controller to present.
    ///   - animated: Should be animated or not.
    ///   - completion: A closure to be executed after the replacement is complete.
    public func present(controller: UIViewController, animated: Bool, completion: (() -> Void)?) {
        if window?.rootViewController != nil {
            window?.topController?.present(
                controller,
                animated: animated,
                completion: completion
            )
        } else {
            var transition: CATransition?
            if animated {
                transition = CATransition()
                transition?.duration = 0.3
                transition?.type = .fade
            }
            replaceWindowRoot(
                controller: controller,
                transition: transition,
                completion: completion
            )
        }
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
                if let navigationController = controller.navigationController {
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
    public func dismissPresented(in controller: UIViewController?, animated: Bool, completion: (() -> Void)?) {
        if let presentedViewController = controller?.presentedViewController {
            presentedViewController.dismiss(animated: animated, completion: { [weak self] in
                if controller?.presentedViewController != nil {
                    self?.dismissPresented(in: controller, animated: animated, completion: completion)
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
    ///   - completion: A closure to be executed after the tab is selected, providing the view controller found in the selected tab if applicable.
    public func selectTabIfNeeded(
        controller: UIViewController?,
        completion: ((UIViewController?) -> Void)? = nil
    ) {
        if let controller, let tabBarController = controller.findTabBarController() {
            for index in (tabBarController.viewControllers ?? []).indices {
                if let sourceController = tabBarController.viewControllers?[index].findController(controller: controller) {
                    if tabBarController.selectedIndex != index {
                        tabBarController.selectedIndex = index
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            completion?(sourceController)
                        }
                    } else {
                        completion?(sourceController)
                    }
                    return
                }
            }
        }
        completion?(nil)
    }

    private func bind() {
        navigationInterceptor?.onInterceptionResolved = { [weak self] reason, newStrategy, prefixNavigationChain, suffixNavigationChain, completion in
            guard let self else { return }

            if let data = navigationInterceptor?.interceptionData.removeValue(forKey: reason) {
                if let newStrategy, !data.chain.isEmpty {
                    data.chain[0].strategy = newStrategy
                }

                navigate(
                    chain: prefixNavigationChain + data.chain + suffixNavigationChain,
                    event: data.event,
                    completion: completion
                )
            }
        }
    }
}
