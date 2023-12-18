//
//  UIWindow+Navigator.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

extension UIWindow {
    public var topController: UIViewController? { topMostViewController?.topController }

    private var topMostViewController: UIViewController? {
        var topmostViewController = rootViewController
        while let presentedViewController = topmostViewController?.presentedViewController, !presentedViewController.isBeingDismissed {
            topmostViewController = presentedViewController
        }

        return topmostViewController
    }

    public func findController(destination: NavigationDestination) -> UIViewController? {
        rootViewController?.findController(destination: destination)
    }

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
