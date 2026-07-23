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
    ///   - completion: A closure called with `true` if the pop was successful, or `false` if there was only one
    ///     view controller.
    func popViewController(
        animated: Bool,
        completion: @escaping (Bool) -> Void
    ) {
        guard canMutateNavigationStack,
            viewControllers.count > 1,
            let previousTop = topViewController
        else {
            completion(false)

            return
        }

        let shouldAnimate = animated && canAnimateNavigationTransition
        var poppedController: UIViewController?
        observeCompletion(
            animated: shouldAnimate,
            operation: { poppedController = popViewController(animated: shouldAnimate) },
            completion: {
                completion(
                    poppedController === previousTop
                        && self.topViewController !== previousTop
                        && !self.viewControllers.contains(where: { $0 === previousTop })
                )
            }
        )
    }

    /// Replaces the current view controllers of the navigation stack.
    /// - Parameters:
    ///   - controllers: The new array of view controllers.
    ///   - animated: Indicates whether the transition is animated.
    ///   - completion: An optional closure executed after the transition finishes.
    func setViewControllers(
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
    func popToViewController(
        _ controller: UIViewController,
        animated: Bool,
        completion: (() -> Void)?
    ) {
        popToViewController(
            controller,
            animated: animated,
            resultCompletion: { _ in completion?() }
        )
    }

    func popToViewController(
        _ controller: UIViewController,
        animated: Bool,
        resultCompletion: @escaping (Bool) -> Void
    ) {
        guard canMutateNavigationStack,
            viewControllers.contains(where: { $0 === controller })
        else {
            resultCompletion(false)

            return
        }

        if topViewController == controller {
            resultCompletion(true)
        } else {
            let shouldAnimate = animated && canAnimateNavigationTransition
            var poppedControllers: [UIViewController]?
            observeCompletion(
                animated: shouldAnimate,
                operation: { poppedControllers = popToViewController(controller, animated: shouldAnimate) },
                completion: {
                    resultCompletion(
                        poppedControllers != nil
                            && self.topViewController === controller
                            && self.viewControllers.contains(where: { $0 === controller })
                    )
                }
            )
        }
    }

    /// Pushes a view controller onto the navigation stack.
    /// - Parameters:
    ///   - viewController: The view controller to push.
    ///   - animated: Indicates whether the transition is animated.
    ///   - completion: An optional closure executed after the transition finishes.
    func pushViewController(
        _ viewController: UIViewController,
        animated: Bool,
        completion: (() -> Void)?
    ) {
        guard canPushViewController(viewController) else {
            completion?()

            return
        }

        let shouldAnimate = animated && canAnimateNavigationTransition
        observeCompletion(
            animated: shouldAnimate,
            operation: { pushViewController(viewController, animated: shouldAnimate) },
            completion: completion
        )
    }

    func canPushViewController(_ viewController: UIViewController) -> Bool {
        return canMutateNavigationStack
            && !(viewController is UINavigationController)
            && !(viewController is UITabBarController)
            && viewController !== self
            && viewController.parent == nil
            && viewController.navigationController == nil
            && viewController.presentingViewController == nil
            && viewController.presentedViewController == nil
            && !viewController.isBeingPresented
            && !viewController.isBeingDismissed
            && viewController.transitionCoordinator == nil
            && viewController.viewIfLoaded?.window == nil
            && !viewControllers.contains(where: { $0 === viewController })
            && viewController.findController(controller: self, withPresented: true) == nil
    }

    func canSetNavigationRoot(_ viewController: UIViewController) -> Bool {
        return canMutateNavigationStack
            && !(viewController is UINavigationController)
            && !(viewController is UITabBarController)
            && viewController !== self
            && (viewController.parent == nil || viewController.parent === self)
            && (viewController.navigationController == nil || viewController.navigationController === self)
            && viewController.presentingViewController == nil
            && viewController.presentedViewController == nil
            && !viewController.isBeingDismissed
            && !viewController.isBeingPresented
            && viewController.transitionCoordinator == nil
            && (viewController.viewIfLoaded?.window == nil || viewController.navigationController === self)
            && viewController.findController(controller: self, withPresented: true) == nil
    }

    var canMutateNavigationStack: Bool {
        return !isBeingPresented
            && !isBeingDismissed
            && transitionCoordinator == nil
            && viewControllers.allSatisfy {
                !$0.isBeingPresented
                    && !$0.isBeingDismissed
                    && $0.transitionCoordinator == nil
            }
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
            DispatchQueue.main.async {
                completion?()
            }

            return
        }

        var didScheduleCompletion = false
        func scheduleCompletionOnce() {
            guard !didScheduleCompletion else { return }

            didScheduleCompletion = true
            DispatchQueue.main.async {
                completion?()
            }
        }

        let registeredCompletion = coordinator.animate(alongsideTransition: nil) { _ in
            scheduleCompletionOnce()
        }
        if !registeredCompletion {
            scheduleCompletionOnce()
        }
    }
}
