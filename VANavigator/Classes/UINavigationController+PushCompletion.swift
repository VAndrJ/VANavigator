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
                let completionDelegate = NavigationCompletionDelegate(completion: completion)
                NavigationCompletionStore.retain(completionDelegate, for: self)
                delegate = completionDelegate
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

private enum NavigationCompletionStore {
    private static var entries: [ObjectIdentifier: NavigationCompletionEntry] = [:]

    static func retain(
        _ completionDelegate: NavigationCompletionDelegate,
        for navigationController: UINavigationController
    ) {
        cleanupReleasedControllers()
        entries[ObjectIdentifier(navigationController)] = NavigationCompletionEntry(
            navigationController: navigationController,
            completionDelegate: completionDelegate
        )
    }

    static func release(for navigationController: UINavigationController) {
        entries[ObjectIdentifier(navigationController)] = nil
        cleanupReleasedControllers()
    }

    private static func cleanupReleasedControllers() {
        entries = entries.filter { $0.value.navigationController != nil }
    }
}

private final class NavigationCompletionEntry {
    weak var navigationController: UINavigationController?
    let completionDelegate: NavigationCompletionDelegate

    init(
        navigationController: UINavigationController,
        completionDelegate: NavigationCompletionDelegate
    ) {
        self.navigationController = navigationController
        self.completionDelegate = completionDelegate
    }
}

private final class NavigationCompletionDelegate: NSObject, UINavigationControllerDelegate {
    var completion: (() -> Void)?

    init(completion: (() -> Void)?) {
        self.completion = completion
    }

    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        let completion = completion
        self.completion = nil
        if navigationController.delegate === self {
            navigationController.delegate = nil
        }
        NavigationCompletionStore.release(for: navigationController)
        completion?()
    }
}
