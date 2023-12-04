//
//  UIWindow+Navigator.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

extension UIWindow {
    var topViewController: UIViewController? { topMostViewController?.topViewController(root: true) }

    private var topMostViewController: UIViewController? {
        var topmostViewController = rootViewController
        while let presentedViewController = topmostViewController?.presentedViewController, !presentedViewController.isBeingDismissed {
            topmostViewController = presentedViewController
        }

        return topmostViewController
    }

    func findController(destination: Navigator.NavigationDestination) -> UIViewController? {
        rootViewController?.findController(destination: destination)
    }

    func set(rootViewController newRootViewController: UIViewController, transition: CATransition? = nil, completion: (() -> Void)? = nil) {
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
        if #unavailable(iOS 13.0) {
            if let transitionViewClass = NSClassFromString("UITransitionView") {
                for subview in subviews where subview.isKind(of: transitionViewClass) {
                    subview.removeFromSuperview()
                }
            }
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
