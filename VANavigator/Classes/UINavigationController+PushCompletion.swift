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

    public func setViewControllers(
        _ controllers: [UIViewController],
        animated: Bool,
        completion: (() -> Void)?
    ) {
        setViewControllers(controllers, animated: animated)
        observeCompletion(animated: animated, completion: completion)
    }

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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
