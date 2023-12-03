//
//  Navigator.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

public final class Navigator {
    public enum NavigationDestination {
        case identity(NavigationIdentity)
        case controller(UIViewController)

        /// Computed property to extract the navigation identity from the destination.
        var identity: NavigationIdentity? {
            switch self {
            case let .identity(identity):
                return identity
            case let .controller(controller):
                return controller.navigationIdentity
            }
        }
    }

    public let screenFactory: NavigatorScreenFactory

    public private(set) weak var window: UIWindow?

    public init(
        window: UIWindow?,
        screenFactory: NavigatorScreenFactory
    ) {
        self.window = window
        self.screenFactory = screenFactory
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

        return navigate(
            destination: link.destination,
            source: source,
            strategy: link.strategy,
            event: event,
            animated: link.animated,
            completion: { [weak self] in
                self?.navigate(
                    chain: chain,
                    source: link.destination.identity,
                    event: event,
                    completion: completion
                )
            }
        )
    }

    // swiftlint:disable function_body_length
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
        let eventController: (UIViewController & Responder)?
        var navigatorEvent: ResponderEvent?
        switch strategy {
        case let .replaceWindowRoot(transition):
            guard let controller = getScreen(destination: destination) else {
                completion?()
                return nil
            }

            if window?.rootViewController != nil {
                navigatorEvent = ResponderReplacedWindowRootControllerEvent()
            }
            replaceWindowRoot(controller: controller, transition: transition, completion: completion)
            eventController = controller as? UIViewController & Responder
        case .present:
            guard let controller = getScreen(destination: destination) else {
                completion?()
                return nil
            }

            present(controller: controller, animated: animated, completion: completion)
            eventController = controller as? UIViewController & Responder
        case .presentOrCloseToExisting:
            if let controller = window?.findController(destination: destination) {
                selectTabIfNeeded(
                    source: source ?? destination.identity?.fallbackSource,
                    controller: window?.topViewController,
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
            guard let controller = getScreen(destination: destination) else {
                completion?()
                return nil
            }

            selectTabIfNeeded(
                source: source ?? destination.identity?.fallbackSource,
                controller: window?.topViewController,
                completion: { [weak self] sourceController in
                    guard let self else {
                        completion?()
                        return
                    }

                    let sourceController = sourceController?.topViewController(root: true)?.orNavigationController
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
        case let .pushOrPopToExisting(alwaysEmbedded):
            if let controller = window?.topViewController?.navigationController?.findController(destination: destination) {
                closeNavigationPresented(controller: controller, animated: animated)
                selectTabIfNeeded(source: source ?? destination.identity?.fallbackSource, controller: controller)
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
        case .replaceNavigationRoot:
            if let navigationController = window?.topViewController?.navigationController {
                guard let controller = getScreen(destination: destination) else {
                    completion?()
                    return nil
                }

                navigationController.setViewControllers([controller], animated: animated)
                eventController = controller as? UIViewController & Responder
                completion?()
            } else {
                return navigate(
                    destination: destination,
                    source: source,
                    strategy: .push(alwaysEmbedded: true),
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
    // swiftlint:enable function_body_length

    /// Retrieves a view controller based on the provided navigation destination.
    ///
    /// - Parameter destination: The navigation destination indicating whether to assemble a screen using an identity or use an existing controller.
    /// - Returns: The view controller corresponding to the given navigation destination.
    func getScreen(destination: NavigationDestination) -> UIViewController? {
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
        if let navigationController = window?.topViewController?.orNavigationController {
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
            window?.topViewController?.present(controller, animated: animated, completion: completion)
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
    ///   - source: The source navigation identity to find in the tab bar controller.
    ///   - controller: The view controller from which to start searching for the tab bar controller.
    ///   - completion: A closure to be executed after the tab is selected, providing the view controller found in the selected tab if applicable.
    func selectTabIfNeeded(
        source: NavigationIdentity?,
        controller: UIViewController?,
        completion: ((UIViewController?) -> Void)? = nil
    ) {
        if let source, let tabBarController = controller?.findTabBarController() {
            for index in (tabBarController.viewControllers ?? []).indices {
                if let sourceController = tabBarController.viewControllers?[index].findController(identity: source) {
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
}

public struct ResponderPoppedToExistingEvent: ResponderEvent {}

public struct ResponderClosedToExistingEvent: ResponderEvent {}

public struct ResponderReplacedWindowRootControllerEvent: ResponderEvent {}
