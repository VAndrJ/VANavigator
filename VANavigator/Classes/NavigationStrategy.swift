//
//  NavigationStrategy.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

@MainActor
public class NavigationStrategy: @MainActor Equatable {
    enum Comparison: Equatable {
        case split(SplitStrategy)
        case closeToExisting
        case removeFromStack
        case present(PresentNavigationSource)
        case replaceNavigationRoot
        case popToExisting(includingTabs: Bool)
        case replaceWindowRoot(transition: ObjectIdentifier?)
        case closeIfTop(tryToPop: Bool, tryToDismiss: Bool)
        case push
        case instance
    }

    let comparison: Comparison

    public static func == (lhs: NavigationStrategy, rhs: NavigationStrategy) -> Bool {
        return lhs.isEqual(to: rhs)
    }

    init(comparison: Comparison) {
        self.comparison = comparison
    }

    func isEqual(to other: NavigationStrategy?) -> Bool {
        guard let other else {
            return false
        }

        switch (comparison, other.comparison) {
        case (.instance, .instance):
            return self === other
        default:
            return comparison == other.comparison
        }
    }
}

extension NavigationStrategy {
    /// Replaces the navigation stack with the given controller as the root or uses fallback if no
    /// `UINavigationController` is found.
    public static var replaceNavigationRoot: NavigationStrategy { ReplaceNavigationRootNavigationStrategy() }
    /// Closes presented controllers to given controller if it exists.
    public static var closeToExisting: NavigationStrategy { CloseToExistingNavigationStrategy() }
    /// Removes an existing controller from the `UINavigationController` stack, or uses fallback if no navigation
    /// controller is found. Does nothing if the target is the last controller.
    public static var removeFromNavigationStack: NavigationStrategy { RemoveFromStackNavigationStrategy() }

    /// Pushes a controller onto the navigation stack, or uses fallback if no `UINavigationController` is found.
    /// - Parameter navigation: UINavigationController to push in.
    /// - Returns: NavigationStrategy.
    public static func push(navigation: ((UINavigationController) -> Void)? = nil) -> NavigationStrategy {
        return PushNavigationStrategy(navigation: navigation)
    }

    /// Presents a controller based on source.
    public static func present(source: PresentNavigationSource = .topController) -> NavigationStrategy {
        return PresentNavigationStrategy(source: source)
    }

    /// Presents a popover.
    public static func popover(
        configure: @escaping (_ popover: UIPopoverPresentationController, _ controller: UIViewController) -> Void
    ) -> NavigationStrategy {
        return PopoverNavigationStrategy(configure: configure)
    }

    /// Close the controller if it is top one
    public static func closeIfTop(
        tryToPop: Bool = true,
        tryToDismiss: Bool = true,
        navigation: ((UINavigationController) -> Void)? = nil
    ) -> NavigationStrategy {
        return CloseIfTopNavigationStrategy(
            tryToPop: tryToPop,
            tryToDismiss: tryToDismiss,
            navigation: navigation
        )
    }

    /// Replaces `UIWindow`'s `rootViewController` with the given `transition`.
    public static func replaceWindowRoot(transition: CATransition? = nil) -> NavigationStrategy {
        return ReplaceWindowRootNavigationStrategy(transition: transition)
    }

    /// Pops to existing controller, or uses fallback if no `UINavigationController` is found.
    public static func popToExisting(includingTabs: Bool = true) -> NavigationStrategy {
        return PopToExistingNavigationStrategy(includingTabs: includingTabs)
    }

    /// Shows in a `UISplitViewController` with the given `strategy`.
    public static func split(strategy: SplitStrategy) -> NavigationStrategy {
        return SplitNavigationStrategy(strategy: strategy)
    }
}

/// Navigation strategy for `UISplitViewController`.
nonisolated public enum SplitStrategy: Sendable, Equatable {
    nonisolated public enum SplitAction: Sendable, Equatable, Hashable {
        /// Pushes the selected view controller in `UISplitViewController`.
        case push
        /// Pops to the selected view controller in `UISplitViewController`.
        case pop
        /// Replaces with the selected view controller in `UISplitViewController`.
        case replace
    }

    /// Backward-compatible spelling retained for clients migrating from VANavigator 4.x.
    @available(*, deprecated, renamed: "SplitAction")
    public typealias SplitActon = SplitAction

    /// Performs action on the primary view controller in `UISplitViewController`.
    case primary(action: SplitAction)
    /// Performs action on the secondary view controller in `UISplitViewController`.
    case secondary(action: SplitAction)
}

final class SplitNavigationStrategy: NavigationStrategy {
    let strategy: SplitStrategy

    init(strategy: SplitStrategy) {
        self.strategy = strategy
        super.init(comparison: .split(strategy))
    }
}

final class PopoverNavigationStrategy: NavigationStrategy {
    let configure: (_ popover: UIPopoverPresentationController, _ controller: UIViewController) -> Void

    init(configure: @escaping (_ popover: UIPopoverPresentationController, _ controller: UIViewController) -> Void) {
        self.configure = configure
        super.init(comparison: .instance)
    }
}

final class CloseToExistingNavigationStrategy: NavigationStrategy {
    init() {
        super.init(comparison: .closeToExisting)
    }
}

final class RemoveFromStackNavigationStrategy: NavigationStrategy {
    init() {
        super.init(comparison: .removeFromStack)
    }
}

nonisolated public enum PresentNavigationSource: Sendable, Equatable, Hashable {
    case topController
    case navigationController
    case tabBarController
}

final class PresentNavigationStrategy: NavigationStrategy {
    let source: PresentNavigationSource

    init(source: PresentNavigationSource) {
        self.source = source
        super.init(comparison: .present(source))
    }
}

final class ReplaceNavigationRootNavigationStrategy: NavigationStrategy {
    init() {
        super.init(comparison: .replaceNavigationRoot)
    }
}

final class PopToExistingNavigationStrategy: NavigationStrategy {
    let includingTabs: Bool

    init(includingTabs: Bool) {
        self.includingTabs = includingTabs
        super.init(comparison: .popToExisting(includingTabs: includingTabs))
    }
}

final class PushNavigationStrategy: NavigationStrategy {
    let navigation: ((UINavigationController) -> Void)?

    init(navigation: ((UINavigationController) -> Void)?) {
        self.navigation = navigation
        super.init(comparison: navigation == nil ? .push : .instance)
    }
}

final class ReplaceWindowRootNavigationStrategy: NavigationStrategy {
    let transition: CATransition?

    init(transition: CATransition? = nil) {
        self.transition = transition
        super.init(comparison: .replaceWindowRoot(transition: transition.map(ObjectIdentifier.init)))
    }
}

final class CloseIfTopNavigationStrategy: NavigationStrategy {
    let tryToPop: Bool
    let tryToDismiss: Bool
    let navigation: ((UINavigationController) -> Void)?

    init(
        tryToPop: Bool,
        tryToDismiss: Bool,
        navigation: ((UINavigationController) -> Void)?
    ) {
        self.tryToPop = tryToPop
        self.tryToDismiss = tryToDismiss
        self.navigation = navigation
        super.init(
            comparison: navigation == nil
                ? .closeIfTop(tryToPop: tryToPop, tryToDismiss: tryToDismiss)
                : .instance
        )
    }
}
