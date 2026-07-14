//
//  UINavigationController+PushCompletion.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

extension UINavigationController {
    /// Pops the top view controller from the navigation stack.
    /// - Parameters:
    ///   - animated: Indicates whether the transition is animated.
    ///   - completion: A closure called with `true` if the pop was successful, or `false` if there was only one view controller.
    public func popViewController(
        animated: Bool,
        completion: @escaping (Bool) -> Void
    ) {
        if viewControllers.count > 1 {
            let shouldAnimate = animated && canAnimateNavigationTransition
            observeCompletion(
                animated: shouldAnimate,
                operation: { popViewController(animated: shouldAnimate) },
                completion: { completion(true) }
            )
        } else {
            completion(false)
        }
    }

    /// Replaces the current view controllers of the navigation stack.
    /// - Parameters:
    ///   - controllers: The new array of view controllers.
    ///   - animated: Indicates whether the transition is animated.
    ///   - completion: An optional closure executed after the transition finishes.
    public func setViewControllers(
        _ controllers: [UIViewController],
        animated: Bool,
        completion: (() -> Void)?
    ) {
        let shouldAnimate = animated && canAnimateNavigationTransition
        observeCompletion(
            animated: shouldAnimate,
            operation: { setViewControllers(controllers, animated: shouldAnimate) },
            completion: completion
        )
    }

    /// Pops view controllers until the specified view controller is at the top of the stack.
    /// - Parameters:
    ///   - controller: The view controller to pop to.
    ///   - animated: Indicates whether the transition is animated.
    ///   - completion: An optional closure executed after the transition finishes.
    public func popToViewController(
        _ controller: UIViewController,
        animated: Bool,
        completion: (() -> Void)?
    ) {
        if topViewController == controller {
            completion?()
        } else {
            let shouldAnimate = animated && canAnimateNavigationTransition
            observeCompletion(
                animated: shouldAnimate,
                operation: { popToViewController(controller, animated: shouldAnimate) },
                completion: completion
            )
        }
    }

    /// Pushes a view controller onto the navigation stack.
    /// - Parameters:
    ///   - viewController: The view controller to push.
    ///   - animated: Indicates whether the transition is animated.
    ///   - completion: An optional closure executed after the transition finishes.
    public func pushViewController(
        _ viewController: UIViewController,
        animated: Bool,
        completion: (() -> Void)?
    ) {
        let shouldAnimate = animated && canAnimateNavigationTransition
        observeCompletion(
            animated: shouldAnimate,
            operation: { pushViewController(viewController, animated: shouldAnimate) },
            completion: completion
        )
    }

    private var canAnimateNavigationTransition: Bool {
        guard let window = viewIfLoaded?.window else { return false }

        return !window.isHidden
            && !window.bounds.isEmpty
            && (window.isKeyWindow || window.windowScene != nil)
    }

    private func observeCompletion(
        animated: Bool,
        operation: () -> Void,
        completion: (() -> Void)?
    ) {
        operation()
        guard animated, let coordinator = transitionCoordinator else {
            completion?()

            return
        }

        coordinator.animate(alongsideTransition: nil) { _ in
            completion?()
        }
    }
}
