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
    ///   - chain: An array of tuples representing the navigation chain with destination and strategy.
    ///   - source: The source navigation identity.
    ///   - event: `ResponderEvent` to be handled by the destination controller.
    ///   - completion: A closure to be executed after the entire navigation chain is complete.
    /// - Returns: The `Responder` representing the destination controller.
    @discardableResult
    public func navigate(
        chain: [(destination: NavigationDestination, strategy: NavigationStrategy, animated: Bool)],
        source: NavigationIdentity? = nil,
        event: ResponderEvent? = nil,
        completion: (() -> Void)? = nil
    ) -> (UIViewController & Responder)? {
        guard !chain.isEmpty else {
            completion?()
            return nil
        }

        var chain = chain
        let link = chain.removeFirst()

        if let navigationInterceptor, let interceptionResult = navigationInterceptor.intercept(destination: link.destination) {
            let chain = ([link] + chain).compactMap { link in
                if let identity = link.destination.identity {
                    return (NavigationDestination.identity(identity), link.strategy, link.animated)
                } else {
                    return nil
                }
            }
            let detail = InterceptionDetail(
                chain: chain,
                source: source,
                event: event,
                completion: completion
            )
            navigationInterceptor.interceptionData[interceptionResult.reason] = detail

            return navigate(
                chain: interceptionResult.chain,
                source: interceptionResult.source,
                event: interceptionResult.event,
                completion: interceptionResult.completion
            )
        }

        return navigate(
            destination: link.destination,
            source: source,
            strategy: link.strategy,
            event: event,
            animated: link.animated,
            completion: { [weak self] in
                DispatchQueue.main.async {
                    self?.navigate(
                        chain: chain,
                        source: link.destination.identity,
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
    ///   - source: The source identity for navigation.
    ///   - strategy: The navigation strategy to be applied.
    ///   - event: `ResponderEvent` to be handled by the destination controller.
    ///   - animated: A flag indicating whether the navigation should be animated.
    ///   - completion: A closure to be executed after the navigation is complete.
    /// - Returns: The `Responder` representing the destination controller.
    @discardableResult
    public func navigate(
        destination: NavigationDestination,
        source: NavigationIdentity? = nil,
        strategy: NavigationStrategy,
        event: ResponderEvent? = nil,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) -> (UIViewController & Responder)? {
        if let navigationInterceptor, let interceptionResult = navigationInterceptor.intercept(destination: destination) {
            if let identity = destination.identity {
                let detail = InterceptionDetail(
                    chain: [(.identity(identity), strategy, animated)],
                    source: source,
                    event: event,
                    completion: completion
                )
                navigationInterceptor.interceptionData[interceptionResult.reason] = detail
            }

            return navigate(
                chain: interceptionResult.chain,
                source: interceptionResult.source,
                event: interceptionResult.event,
                completion: interceptionResult.completion
            )
        }

        let eventController: (UIViewController & Responder)?
        var navigatorEvent: ResponderEvent?
        switch strategy {
        case let .closeIfTop(tryToPop, tryToDismiss):
            if let controller = window?.topController {
                if tryToPop, controller.navigationController?.topViewController?.navigationIdentity?.isEqual(to: destination.identity) == true  {
                    controller.navigationController?.popViewController(animated: animated, completion: completion)
                } else {
                    if tryToDismiss {
                        controller.dismiss(animated: animated, completion: completion)
                    } else {
                        completion?()
                    }
                }
            } else {
                completion?()
            }
            return nil
        case let .replaceWindowRoot(transition, alwaysEmbedded):
            let controller = getController(destination: destination)
            if window?.rootViewController != nil {
                navigatorEvent = ResponderReplacedWindowRootControllerEvent()
            }
            replaceWindowRoot(
                controller: alwaysEmbedded ? screenFactory.embedInNavigationControllerIfNeeded(controller: controller) : controller,
                transition: transition,
                completion: completion
            )
            eventController = controller as? UIViewController & Responder
        case .present:
            let controller = getController(destination: destination)
            present(controller: controller, animated: animated, completion: completion)
            eventController = controller as? UIViewController & Responder
        case .presentOrCloseToExisting:
            if let controller = window?.findController(destination: destination) {
                selectTabIfNeeded(
                    controller: window?.topController,
                    completion: { [weak self] sourceController in
                        self?.closeNavigationPresented(controller: sourceController ?? controller, animated: animated)
                        completion?()
                    }
                )
                eventController = controller as? UIViewController & Responder
                navigatorEvent = ResponderClosedToExistingEvent()
            } else {
                return navigate(
                    destination: destination,
                    source: source,
                    strategy: .present,
                    event: event,
                    animated: animated,
                    completion: completion
                )
            }
        case let .push(alwaysEmbedded):
            let controller = getController(destination: destination)
            selectTabIfNeeded(
                controller: window?.topController,
                completion: { [weak self] sourceController in
                    guard let self else {
                        completion?()
                        return
                    }

                    let sourceController = sourceController?.topController.orNavigationController
                    if !push(sourceController: sourceController, controller: controller, animated: animated, completion: completion) {
                        navigate(
                            destination: .controller(alwaysEmbedded ? screenFactory.embedInNavigationControllerIfNeeded(controller: controller) : controller),
                            source: source,
                            strategy: .present,
                            event: event,
                            animated: animated,
                            completion: completion
                        )
                    }
                }
            )
            eventController = controller as? UIViewController & Responder
        case let .pushOrPopToExisting(alwaysEmbedded, includingTabs):
            func getController() -> UIViewController? {
                let topController = window?.topController
                return includingTabs ?
                topController?.orTabBarController?.findController(destination: destination) ?? topController?.orNavigationController?.findController(destination: destination) :
                topController?.orNavigationController?.findController(destination: destination)
            }

            if let controller = getController() {
                closeNavigationPresented(controller: controller, animated: animated)
                selectTabIfNeeded(controller: controller)
                eventController = controller as? UIViewController & Responder
                navigatorEvent = ResponderPoppedToExistingEvent()
                completion?()
            } else {
                return navigate(
                    destination: destination,
                    source: source,
                    strategy: .push(alwaysEmbedded: alwaysEmbedded),
                    event: event,
                    animated: animated,
                    completion: completion
                )
            }
        case let .replaceNavigationRoot(alwaysEmbedded):
            if let navigationController = window?.topController?.navigationController {
                let controller = getController(destination: destination)
                navigationController.setViewControllers([controller], animated: animated)
                eventController = controller as? UIViewController & Responder
                completion?()
            } else {
                return navigate(
                    destination: destination,
                    source: source,
                    strategy: .push(alwaysEmbedded: alwaysEmbedded),
                    event: event,
                    animated: animated,
                    completion: completion
                )
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
                                source: source,
                                strategy: .replaceNavigationRoot(),
                                event: event,
                                animated: animated,
                                completion: completion
                            )
                        } else {
                            let controller = getController(destination: destination)
                            splitController.setViewController(controller, for: .primary)
                            eventController = controller as? UIViewController & Responder
                        }
                    } else {
                        let controller = getController(destination: destination)
                        splitController.viewControllers = [controller]
                        eventController = controller as? UIViewController & Responder
                    }
                case let .secondary(shouldPop):
                    if #available(iOS 14.0, *) {
                        if splitController.isSingleNavigation {
                            return navigate(
                                destination: destination,
                                source: source,
                                strategy: shouldPop ? .pushOrPopToExisting() : .push(),
                                event: event,
                                animated: animated,
                                completion: completion
                            )
                        } else {
                            if let navigationController = splitController.viewController(for: .secondary)?.navigationController,
                               shouldPop,
                               let controller = navigationController.findController(destination: destination) {

                                dismissPresented(in: navigationController, animated: animated)
                                navigationController.popToViewController(controller, animated: animated)
                                eventController = controller as? UIViewController & Responder
                                navigatorEvent = ResponderPoppedToExistingEvent()
                            } else {
                                let controller = getController(destination: destination)
                                dismissPresented(in: splitController, animated: animated)
                                eventController = controller as? UIViewController & Responder
                                splitController.setViewController(controller, for: .secondary)
                            }
                        }
                    } else {
                        let controller = getController(destination: destination)
                        dismissPresented(in: splitController, animated: animated)
                        splitController.showDetailViewController(controller, sender: nil)
                        eventController = controller as? UIViewController & Responder
                    }
                    completion?()
                case let .replaceSecondary(shouldPop):
                    if #available(iOS 14.0, *) {
                        if splitController.isSingleNavigation {
                            return navigate(
                                destination: destination,
                                source: source,
                                strategy: shouldPop ? .pushOrPopToExisting() : .push(),
                                event: event,
                                animated: animated,
                                completion: completion
                            )
                        } else {
                            if let navigationController = splitController.viewController(for: .secondary)?.navigationController {
                                if shouldPop, navigationController.viewControllers.first?.navigationIdentity?.isEqual(to: destination.identity) == true {
                                    dismissPresented(in: navigationController, animated: animated)
                                    navigationController.popToRootViewController(animated: animated)
                                    eventController = navigationController.viewControllers.first as? UIViewController & Responder
                                    navigatorEvent = ResponderPoppedToExistingEvent()
                                } else {
                                    let controller = getController(destination: destination)
                                    dismissPresented(in: navigationController, animated: animated)
                                    navigationController.setViewControllers([controller], animated: animated)
                                    eventController = controller as? UIViewController & Responder
                                }
                            } else {
                                let controller = getController(destination: destination)
                                dismissPresented(in: splitController, animated: animated)
                                splitController.setViewController(controller, for: .secondary)
                                eventController = controller as? UIViewController & Responder
                            }
                        }
                    } else {
                        let controller = getController(destination: destination)
                        dismissPresented(in: splitController, animated: animated)
                        splitController.viewControllers = splitController.viewControllers.first.flatMap { [$0, controller] } ?? [controller]
                        eventController = controller as? UIViewController & Responder
                    }
                case let .replaceSupplementary(shouldPop):
                    if #available(iOS 14.0, *) {
                        if splitController.isSingleNavigation {
                            return navigate(
                                destination: destination,
                                source: source,
                                strategy: shouldPop ? .pushOrPopToExisting() : .push(),
                                event: event,
                                animated: animated,
                                completion: completion
                            )
                        } else {
                            if splitController.style == .tripleColumn {
                                if let navigationController = splitController.viewController(for: .supplementary)?.navigationController {
                                    if shouldPop, navigationController.viewControllers.first?.navigationIdentity?.isEqual(to: destination.identity) == true {
                                        dismissPresented(in: navigationController, animated: animated)
                                        navigationController.popToRootViewController(animated: animated)
                                        eventController = navigationController.viewControllers.first as? UIViewController & Responder
                                        navigatorEvent = ResponderPoppedToExistingEvent()
                                    } else {
                                        let controller = getController(destination: destination)
                                        dismissPresented(in: navigationController, animated: animated)
                                        navigationController.setViewControllers([controller], animated: animated)
                                        eventController = controller as? UIViewController & Responder
                                    }
                                } else {
                                    let controller = getController(destination: destination)
                                    dismissPresented(in: splitController, animated: animated)
                                    splitController.setViewController(controller, for: .supplementary)
                                    eventController = controller as? UIViewController & Responder
                                }
                            } else {
                                return navigate(
                                    destination: destination,
                                    source: source,
                                    strategy: .showSplit(strategy: .secondary(shouldPop: shouldPop)),
                                    event: event,
                                    animated: animated,
                                    completion: completion
                                )
                            }
                        }
                    } else {
                        let controller = getController(destination: destination)
                        dismissPresented(in: splitController, animated: animated)
                        splitController.viewControllers = Array(splitController.viewControllers.prefix(2)) + [controller]
                        eventController = controller as? UIViewController & Responder
                    }
                }
                completion?()
            } else {
                return navigate(
                    destination: source.flatMap { .identity($0) } ?? destination,
                    source: nil,
                    strategy: .present,
                    event: event,
                    animated: animated,
                    completion: completion
                )
            }
        }
        if let navigatorEvent {
            Task {
                await eventController?.handle(event: navigatorEvent)
            }
        }
        if let event {
            Task {
                await eventController?.handle(event: event)
            }
        }

        return eventController
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
    ///   - completion: A closure to be executed after the push is complete.
    /// - Returns: A boolean value indicating whether the push operation was successful. `true` if successful, `false` if a navigation controller was not found.
    func push(
        sourceController: UIViewController?,
        controller: UIViewController,
        animated: Bool,
        completion: (() -> Void)?
    ) -> Bool {
        dismissPresented(in: sourceController, animated: animated)
        if let navigationController = window?.topController?.orNavigationController {
            navigationController.pushViewController(
                controller,
                animated: animated,
                completion: completion
            )

            return true
        } else {
            return false
        }
    }

    /// Presents a view controller from the current top controller in the window or sets it as the `rootViewController` if the window is empty.
    ///
    /// - Parameters:
    ///   - controller: The view controller to present.
    ///   - animated: Should be animated or not.
    ///   - completion: A closure to be executed after the replacement is complete.
    func present(controller: UIViewController, animated: Bool, completion: (() -> Void)?) {
        if window?.rootViewController != nil {
            window?.topController?.present(controller, animated: animated, completion: completion)
        } else {
            var transition: CATransition?
            if animated {
                transition = CATransition()
                transition?.duration = 0.3
                transition?.type = .fade
            }
            replaceWindowRoot(controller: controller, transition: transition, completion: completion)
        }
    }

    /// Replaces the root view controller of the window or sets it as the initial root view controller.
    ///
    /// - Parameters:
    ///   - controller: The view controller to set as the `rootViewController`.
    ///   - transition: Animated transitions when replacing the `rootViewController`.
    ///   - completion: A closure to be executed after the replacement is complete.
    func replaceWindowRoot(controller: UIViewController, transition: CATransition?, completion: (() -> Void)?) {
        if window?.rootViewController == nil {
            window?.rootViewController = controller
            window?.makeKeyAndVisible()
            completion?()
        } else {
            window?.set(rootViewController: controller, transition: transition, completion: completion)
        }
    }

    /// Dismisses all presented view controllers within the given controller while they are being presented and pops back to the specified controller in the navigation stack if it exists.
    ///
    /// - Parameters:
    ///   - controller: Controller with presented controllers to dismiss and the target for navigation stack pop.
    ///   - animated: Should be animated or not.
    func closeNavigationPresented(controller: UIViewController?, animated: Bool) {
        if let controller {
            dismissPresented(in: controller, animated: animated)
            controller.navigationController?.popToViewController(controller, animated: animated)
        }
    }

    /// Dismisses all presented view controllers within the given controller while they are being presented.
    ///
    /// - Parameters:
    ///   - controller: Controller with presented controllers to dismiss.
    ///   - animated: Should be animated or not.
    func dismissPresented(in controller: UIViewController?, animated: Bool) {
        controller?.presentedViewController?.dismiss(animated: animated, completion: { [weak self] in
            if controller?.presentedViewController != nil {
                self?.dismissPresented(in: controller, animated: animated)
            }
        })
    }

    /// Selects the tab in the tab bar controller, if needed, based on the provided source identity.
    ///
    /// - Parameters:
    ///   - controller: The view controller from which to start searching for the tab bar controller.
    ///   - completion: A closure to be executed after the tab is selected, providing the view controller found in the selected tab if applicable.
    func selectTabIfNeeded(
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
        navigationInterceptor?.onInterceptionResolved = { [weak self] reason, newStrategy in
            guard let self else { return }

            if let data = navigationInterceptor?.interceptionData.removeValue(forKey: reason) {
                guard !data.chain.isEmpty else {
                    return
                }

                if let newStrategy {
                    data.chain[0].strategy = newStrategy
                }
                navigate(
                    chain: data.chain,
                    source: data.source,
                    event: data.event,
                    completion: data.completion
                )
            }
        }
    }
}
