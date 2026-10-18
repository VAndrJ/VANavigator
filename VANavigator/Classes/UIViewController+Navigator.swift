//
//  UIViewController+Navigator.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

extension UIViewController {
    /// Returns the receiver when it is a `UINavigationController`; otherwise returns its `navigationController`.
    public var orNavigationController: UINavigationController? {
        (self as? UINavigationController) ?? navigationController
    }
    /// Returns the receiver when it is a `UITabBarController`; otherwise returns its `tabBarController`.
    public var orTabBarController: UITabBarController? { (self as? UITabBarController) ?? tabBarController }
    /// Returns the receiver when it is a `UISplitViewController`; otherwise returns its `splitViewController`.
    public var orSplitViewController: UISplitViewController? {
        (self as? UISplitViewController) ?? splitViewController
    }
    /// Recursively finds the top-most view controller in the current hierarchy.
    /// This includes the selected tab in `UITabBarController`, the top view controller in `UINavigationController`,
    /// the visible detail column in `UISplitViewController`, children of custom containers, and any presented view
    /// controller.
    ///
    /// UIKit does not define a generic active-child API for custom containers. For those containers, the navigator uses
    /// the last non-dismissing child whose view is attached to a window, falling back to the last non-dismissing child.
    public var topController: UIViewController {
        if let presentedViewController, !presentedViewController.isBeingDismissed {
            return presentedViewController.topController
        }

        var possibleController: UIViewController?
        if let tabBarController = self as? UITabBarController {
            possibleController = tabBarController.selectedViewController
        } else if let navigationController = self as? UINavigationController {
            possibleController = navigationController.topViewController
        } else if let splitController = self as? UISplitViewController {
            possibleController = splitController.navigatorVisibleViewController
        } else {
            possibleController = children.last {
                !$0.isBeingDismissed && $0.viewIfLoaded?.window != nil
            } ?? children.last { !$0.isBeingDismissed }
        }

        if let possibleController, possibleController !== self, !possibleController.isBeingDismissed {
            return possibleController.topController
        } else {
            return self
        }
    }

    /// Recursively searches for a specific `UIViewController` instance within the current view controller's hierarchy.
    /// - Parameters:
    ///   - controller: The view controller instance to find.
    ///   - withPresented: If `true`, the search includes presented view controllers.
    /// - Returns: The found view controller or `nil` if not found.
    public func findController(
        controller: UIViewController,
        withPresented: Bool
    ) -> UIViewController? {
        if self === controller {
            return self
        }
        for child in navigatorSearchChildren {
            if let target = child.findController(
                controller: controller,
                withPresented: withPresented
            ) {
                return target
            }
        }
        if withPresented, let presentedViewController {
            return presentedViewController.findController(
                controller: controller,
                withPresented: withPresented
            )
        }

        return nil
    }

    /// Recursively searches for a view controller with a specific navigation identity within the current hierarchy.
    /// - Parameters:
    ///   - identity: The navigation identity to match.
    ///   - withPresented: If `true`, the search includes presented view controllers.
    /// - Returns: The visible match nearest the top of the hierarchy, or `nil` if no match is found.
    public func findController(
        identity: any NavigationIdentity,
        withPresented: Bool
    ) -> UIViewController? {
        if withPresented,
            let presentedViewController,
            !presentedViewController.isBeingDismissed,
            let target = presentedViewController.findController(
                identity: identity,
                withPresented: withPresented
            )
        {
            return target
        }
        for controller in navigatorSearchChildren {
            if let target = controller.findController(
                identity: identity,
                withPresented: withPresented
            ) {
                return target
            }
        }
        if navigationIdentity?.isEqual(to: identity) == true {
            return self
        }

        return nil
    }

    /// Recursively finds the nearest `UITabBarController` in the view controller hierarchy.
    /// - Returns: The found `UITabBarController` or `nil` if none is found.
    public func findTabBarController() -> UITabBarController? {
        if let tabController = self as? UITabBarController {
            return tabController
        } else if let tabBarController {
            return tabBarController
        } else if let presentingViewController {
            return presentingViewController.findTabBarController()
        } else {
            return nil
        }
    }

    /// Recursively searches for a view controller matching a `NavigationDestination`.
    /// - Parameters:
    ///   - destination: The navigation destination to search for.
    ///   - withPresented: If `true`, the search includes presented view controllers. Defaults to `false`.
    /// - Returns: The found view controller or `nil` if not found.
    public func findController(
        destination: NavigationDestination,
        withPresented: Bool = false
    ) -> UIViewController? {
        switch destination {
        case let .identity(identity):
            return findController(
                identity: identity,
                withPresented: withPresented
            )
        case let .controller(controller):
            return findController(
                controller: controller,
                withPresented: withPresented
            )
        }
    }

    var containsActiveNavigatorTransition: Bool {
        if isBeingPresented || isBeingDismissed || transitionCoordinator != nil {
            return true
        }
        if children.contains(where: { $0.containsActiveNavigatorTransition }) {
            return true
        }

        return presentedViewController?.containsActiveNavigatorTransition ?? false
    }

    /// Includes assigned split columns even while UIKit detaches them from the visible hierarchy.
    func navigatorHierarchyPath(to controller: UIViewController) -> [UIViewController]? {
        if self === controller { return [self] }
        for child in navigatorSearchChildren {
            if let path = child.navigatorHierarchyPath(to: controller) {
                return [self] + path
            }
        }
        if let path = presentedViewController?.navigatorHierarchyPath(to: controller) {
            return [self] + path
        }

        return nil
    }

    private var navigatorSearchChildren: [UIViewController] {
        if let navigationController = self as? UINavigationController {
            return Array(navigationController.viewControllers.reversed())
        } else if let tabBarController = self as? UITabBarController {
            let controllers = tabBarController.viewControllers ?? []
            guard let selectedController = tabBarController.selectedViewController else {
                return Array(controllers.reversed())
            }

            return [selectedController] + controllers.reversed().filter { $0 !== selectedController }
        } else if let splitViewController = self as? UISplitViewController {
            let controllers = splitViewController.navigatorContainedViewControllers
            guard let visibleController = splitViewController.navigatorVisibleViewController else {
                return Array(controllers.reversed())
            }

            return [visibleController] + controllers.reversed().filter { $0 !== visibleController }
        } else {
            let controllers = Array(children.reversed())
            guard let visibleController = controllers.first(where: { $0.viewIfLoaded?.window != nil }) else {
                return controllers
            }

            return [visibleController] + controllers.filter { $0 !== visibleController }
        }
    }
}

extension UISplitViewController {
    @UniqueAddress private static var navigatorActiveColumnKey

    /// Returns the navigation controller UIKit uses for a split-view column.
    ///
    /// UIKit creates this controller when a non-navigation controller is assigned to a column. Starting in iOS 26,
    /// `viewController(for:)` continues to return the assigned controller instead of the generated navigation wrapper,
    /// so callers should use this method when they need to operate on the column's navigation stack.
    /// Returns `nil` for classic (`.unspecified`) split views, which do not support column APIs.
    public func columnNavigationController(for column: Column) -> UINavigationController? {
        guard style != .unspecified, let controller = viewController(for: column) else { return nil }
        if let navigationController = controller.orNavigationController {
            return navigationController
        }

        return navigatorContainedViewControllers
            .compactMap { $0 as? UINavigationController }
            .first { $0.findController(controller: controller, withPresented: false) != nil }
    }

    /// Returns whether the split view currently exposes a single navigation hierarchy.
    public var isSingleNavigation: Bool {
        guard viewControllers.count == 1, let controller = viewControllers.first else { return false }

        return controller is UINavigationController
            || controller.navigationController != nil
            || navigatorContainedViewControllers.contains { $0 is UINavigationController }
    }

    fileprivate var navigatorContainedViewControllers: [UIViewController] {
        var candidates = children + viewControllers
        if style != .unspecified {
            for column in navigatorColumns {
                guard let controller = viewController(for: column) else { continue }
                candidates.append(controller)
                if let navigationController = controller.orNavigationController {
                    candidates.append(navigationController)
                }
            }
        }
        var result: [UIViewController] = []
        for controller in candidates where !result.contains(where: { $0 === controller }) {
            result.append(controller)
        }

        return result
    }

    func navigatorColumn(containing controller: UIViewController) -> Column? {
        guard style != .unspecified else { return nil }

        // Prefer the most specific column when UIKit merges secondary navigation into the primary stack.
        return navigatorColumns.first { column in
            let assigned = viewController(for: column)
            return assigned?.findController(controller: controller, withPresented: true) != nil
                || columnNavigationController(for: column)?.findController(controller: controller, withPresented: true) != nil
        }
    }

    fileprivate var navigatorVisibleViewController: UIViewController? {
        guard style != .unspecified else {
            return viewControllers.last { !$0.isBeingDismissed && $0.viewIfLoaded?.window != nil }
                ?? viewControllers.last { !$0.isBeingDismissed }
        }

        if let compactController = navigatorVisibleController(for: .compact) {
            return compactController
        }

        if let activeColumn = navigatorActiveColumn,
            let activeController = columnNavigationController(for: activeColumn) ?? viewController(for: activeColumn),
            activeController.viewIfLoaded?.window != nil {
            return activeController
        }

        let visibleController = navigatorColumns
            .lazy
            .compactMap { self.columnNavigationController(for: $0) ?? self.viewController(for: $0) }
            .first { $0.viewIfLoaded?.window != nil }

        return visibleController
            ?? navigatorContainedViewControllers.last { $0.viewIfLoaded?.window != nil }
            ?? viewControllers.last
            ?? children.last
    }

    private var navigatorColumns: [Column] {
        var columns: [Column] = [.compact]
        if #available(iOS 26.0, *) {
            columns.append(.inspector)
        }
        columns.append(contentsOf: [.secondary, .supplementary, .primary])

        return columns
    }

    private var navigatorActiveColumn: Column? {
        get {
            (objc_getAssociatedObject(self, Self.navigatorActiveColumnKey) as? NavigatorSplitColumn)?.value
        }
        set {
            objc_setAssociatedObject(
                self,
                Self.navigatorActiveColumnKey,
                newValue.map(NavigatorSplitColumn.init),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    func showNavigatorColumn(
        _ column: Column,
        completion: @escaping () -> Void
    ) {
        var didComplete = false
        func completeOnce() {
            guard !didComplete else { return }

            didComplete = true
            DispatchQueue.main.async {
                completion()
            }
        }

        navigatorActiveColumn = column
        show(column)
        guard let transitionCoordinator else {
            completeOnce()

            return
        }

        let registeredCompletion = transitionCoordinator.animate(alongsideTransition: nil) { _ in
            completeOnce()
        }
        if !registeredCompletion {
            completeOnce()
        }
    }

    private func navigatorVisibleController(for column: Column) -> UIViewController? {
        let controller = columnNavigationController(for: column) ?? viewController(for: column)

        return controller?.viewIfLoaded?.window == nil ? nil : controller
    }
}

private final class NavigatorSplitColumn: NSObject {
    let value: UISplitViewController.Column

    init(_ value: UISplitViewController.Column) {
        self.value = value
    }
}
