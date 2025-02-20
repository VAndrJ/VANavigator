//
//  UINavigationController+PushCompletion.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

extension UINavigationController {
    static let completionDelegate = NavigationCompletionDelegate()

    /// Pops the top view controller from the navigation stack.
    /// - Parameters:
    ///   - animated: Indicates whether the transition is animated.
    ///   - completion: A closure called with `true` if the pop was successful, or `false` if there was only one view controller.
    public func popViewController(
        animated: Bool,
        completion: @escaping (Bool) -> Void
    ) {
        if viewControllers.count > 1 {
            popViewController(animated: animated)
            observeCompletion(animated: animated, completion: { completion(true) })
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
        setViewControllers(controllers, animated: animated)
        observeCompletion(animated: animated, completion: completion)
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
            popToViewController(controller, animated: animated)
            observeCompletion(animated: animated, completion: completion)
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
        pushViewController(viewController, animated: animated)
        observeCompletion(animated: animated, completion: completion)
    }

    private func observeCompletion(animated: Bool, completion: (() -> Void)?) {
        if animated {
            if delegate == nil {
                Self.completionDelegate.completion = { [weak self] in
                    if self?.delegate === Self.completionDelegate {
                        self?.delegate = nil
                    }
                    Self.completionDelegate.completion = nil
                    completion?()
                }
                delegate = Self.completionDelegate
            } else {
                if let coordinator = transitionCoordinator {
                    coordinator.animate(alongsideTransition: nil) { _ in
                        completion?()
                    }
                } else {
                    completion?()
                }
            }
        } else {
            completion?()
        }
    }
}

final class NavigationCompletionDelegate: NSObject, UINavigationControllerDelegate {
    var completion: (() -> Void)?

    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        completion?()
    }
}
