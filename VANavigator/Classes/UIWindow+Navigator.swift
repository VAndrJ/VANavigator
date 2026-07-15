//
//  UIWindow+Navigator.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

private final class RootTransitionCompletionDelegate: NSObject, @preconcurrency CAAnimationDelegate {
    private var forwardedDelegate: (any CAAnimationDelegate)?
    private var onCompletion: ((RootTransitionCompletionDelegate) -> Void)?

    init(
        forwarding forwardedDelegate: (any CAAnimationDelegate)?,
        onCompletion: @escaping (RootTransitionCompletionDelegate) -> Void
    ) {
        self.forwardedDelegate = forwardedDelegate
        self.onCompletion = onCompletion
    }

    func animationDidStart(_ anim: CAAnimation) {
        forwardedDelegate?.animationDidStart?(anim)
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        forwardedDelegate?.animationDidStop?(anim, finished: flag)
        forwardedDelegate = nil
        let onCompletion = self.onCompletion
        self.onCompletion = nil
        onCompletion?(self)
    }
}

private final class RootTransitionCompletionStore: NSObject {
    var delegates: [RootTransitionCompletionDelegate] = []
}

extension UIWindow {
    @UniqueAddress private static var rootTransitionCompletionStoreKey

    private var rootTransitionCompletionStore: RootTransitionCompletionStore {
        if let store = objc_getAssociatedObject(
            self,
            Self.rootTransitionCompletionStoreKey
        ) as? RootTransitionCompletionStore {
            return store
        }

        let store = RootTransitionCompletionStore()
        objc_setAssociatedObject(
            self,
            Self.rootTransitionCompletionStoreKey,
            store,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        return store
    }

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

        func replaceRoot() {
            if let transition {
                let windowTransition = transition.copy() as? CATransition ?? transition
                if let completion {
                    let delegate = RootTransitionCompletionDelegate(
                        forwarding: windowTransition.delegate,
                        onCompletion: { [weak self] delegate in
                            self?.rootTransitionCompletionStore.delegates.removeAll { $0 === delegate }
                            completion()
                        }
                    )
                    rootTransitionCompletionStore.delegates.append(delegate)
                    windowTransition.delegate = delegate
                }
                layer.add(windowTransition, forKey: kCATransition)
                rootViewController = newRootViewController
                newRootViewController.setNeedsStatusBarAppearanceUpdate()
            } else {
                rootViewController = newRootViewController
                newRootViewController.setNeedsStatusBarAppearanceUpdate()
                completion?()
            }
        }

        if previousViewController?.presentedViewController != nil {
            previousViewController?.dismiss(animated: false) {
                replaceRoot()
            }
        } else {
            replaceRoot()
        }
    }
}
