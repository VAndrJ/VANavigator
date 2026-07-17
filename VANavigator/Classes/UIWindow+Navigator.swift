//
//  UIWindow+Navigator.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

/// Core Animation does not express an actor guarantee for delegate callbacks. This delegate keeps
/// its callback state behind a lock and explicitly returns window work to the main actor.
nonisolated private final class RootTransitionCompletionDelegate: NSObject, CAAnimationDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var forwardedDelegate: (any CAAnimationDelegate)?
    private var onCompletion: (@MainActor (RootTransitionCompletionDelegate) -> Void)?
    private var didStop = false

    @MainActor
    init(
        forwarding forwardedDelegate: (any CAAnimationDelegate)?,
        onCompletion: @escaping @MainActor (RootTransitionCompletionDelegate) -> Void
    ) {
        self.forwardedDelegate = forwardedDelegate
        self.onCompletion = onCompletion
    }

    func animationDidStart(_ anim: CAAnimation) {
        lock.lock()
        let forwardedDelegate = didStop ? nil : self.forwardedDelegate
        lock.unlock()
        forwardedDelegate?.animationDidStart?(anim)
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        lock.lock()
        guard !didStop else {
            lock.unlock()

            return
        }
        didStop = true
        let forwardedDelegate = self.forwardedDelegate
        lock.unlock()

        forwardedDelegate?.animationDidStop?(anim, finished: flag)
        Task { @MainActor [self] in
            completeOnMainActor()
        }
    }

    @MainActor
    private func completeOnMainActor() {
        lock.lock()
        let forwardedDelegate = self.forwardedDelegate
        self.forwardedDelegate = nil
        let onCompletion = self.onCompletion
        self.onCompletion = nil
        lock.unlock()
        withExtendedLifetime(forwardedDelegate) {
            onCompletion?(self)
        }
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
    func set(
        rootViewController newRootViewController: UIViewController,
        transition: CATransition? = nil,
        completion: (() -> Void)? = nil
    ) {
        let previousViewController = rootViewController

        guard canSetNavigatorRootViewController(newRootViewController) else {
            completion?()

            return
        }

        func replaceRoot() {
            guard rootViewController === previousViewController,
                canFinishSettingNavigatorRootViewController(newRootViewController)
            else {
                completion?()

                return
            }

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

    func canSetNavigatorRootViewController(_ controller: UIViewController) -> Bool {
        guard controller.parent == nil,
            !controller.isBeingPresented,
            !controller.isBeingDismissed,
            controller.transitionCoordinator == nil,
            rootViewController.map({ !containsActiveNavigatorTransition(in: $0) }) ?? true
        else {
            return false
        }

        if rootViewController === controller {
            return controller.presentingViewController == nil
                && (controller.viewIfLoaded?.window.map { $0 === self } ?? true)
        }

        if controller.presentingViewController == nil {
            return controller.viewIfLoaded?.window == nil
        }

        return controller.viewIfLoaded?.window === self
            && rootViewController?.findController(controller: controller, withPresented: true) != nil
    }

    private func canFinishSettingNavigatorRootViewController(_ controller: UIViewController) -> Bool {
        if rootViewController === controller {
            return controller.parent == nil
                && controller.presentingViewController == nil
                && !controller.isBeingPresented
                && !controller.isBeingDismissed
                && controller.transitionCoordinator == nil
                && (controller.viewIfLoaded?.window.map { $0 === self } ?? true)
        }

        return controller.parent == nil
            && controller.presentingViewController == nil
            && !controller.isBeingPresented
            && !controller.isBeingDismissed
            && controller.transitionCoordinator == nil
            && controller.viewIfLoaded?.window == nil
    }

    func containsActiveNavigatorTransition(in controller: UIViewController) -> Bool {
        if controller.isBeingPresented
            || controller.isBeingDismissed
            || controller.transitionCoordinator != nil
        {
            return true
        }
        if controller.children.contains(where: containsActiveNavigatorTransition(in:)) {
            return true
        }
        if let presentedViewController = controller.presentedViewController {
            return containsActiveNavigatorTransition(in: presentedViewController)
        }

        return false
    }
}
