//
//  UIWindow+Navigator.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

extension UIWindow {
    /// Returns the top-most view controller in the window's view controller hierarchy.
    public var topController: UIViewController? { topMostViewController?.topController }

    private var topMostViewController: UIViewController? {
        var topmostViewController = rootViewController
        while let presentedViewController = topmostViewController?.presentedViewController,
            !presentedViewController.isBeingDismissed {
            topmostViewController = presentedViewController
        }

        return topmostViewController
    }

    /// Recursively searches the window's root view controller for a view controller matching a `NavigationDestination`.
    /// - Parameters:
    ///   - destination: The navigation destination to search for.
    ///   - withPresented: If `true`, the search includes presented view controllers. Defaults to `true`.
    /// - Returns: The found view controller or `nil` if not found.
    public func findController(
        destination: NavigationDestination,
        withPresented: Bool = true
    ) -> UIViewController? {
        rootViewController?.findController(
            destination: destination,
            withPresented: withPresented
        )
    }

    /// Replaces the window's root view controller with a new one, optionally using a transition animation.
    /// - Parameters:
    ///   - newRootViewController: The new view controller to set as the root.
    ///   - transition: An optional `CATransition` animation. If provided, it will be applied to the window's layer.
    ///   - completion: An optional completion handler executed after the transition completes.
    public func set(
        rootViewController newRootViewController: UIViewController,
        transition: CATransition? = nil,
        completion: (() -> Void)? = nil
    ) {
        let previousViewController = rootViewController
        if let transition {
            layer.add(transition, forKey: kCATransition)
        }
        rootViewController = newRootViewController
        if UIView.areAnimationsEnabled {
            UIView.animate(withDuration: CATransaction.animationDuration()) {
                newRootViewController.setNeedsStatusBarAppearanceUpdate()
            }
        } else {
            newRootViewController.setNeedsStatusBarAppearanceUpdate()
        }
        if let previousViewController {
            previousViewController.dismiss(animated: false) {
                previousViewController.view.removeFromSuperview()
                completion?()
            }
        } else {
            completion?()
        }
    }
}
