//
//  NavigationStrategy.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

public class NavigationStrategy: @unchecked Sendable, Equatable {
    public static func == (lhs: NavigationStrategy, rhs: NavigationStrategy) -> Bool {
        lhs.isEqual(to: rhs)
    }

    func isEqual(to other: NavigationStrategy?) -> Bool {
        guard (other as? Self) != nil else {
            return false
        }

        return true
    }
}

public extension NavigationStrategy {
    /// Replaces the navigation stack with the given controller as the root or uses fallback if no `UINavigationController` is found.
    static var replaceNavigationRoot: NavigationStrategy { ReplaceNavigationRootNavigationStrategy() }
    /// Closes presented controllers to given controller if it exists.
    static var closeToExisting: NavigationStrategy { CloseToExistingNavigationStrategy() }
    /// Rmoves an existing controller from the UINavigationController's stack, or uses fallback if no `UINavigationController` is found. Ignores if one is the last controller.
    static var removeFromNavigationStack: NavigationStrategy {
        RemoveFromStackNavigationStrategy()
    }

    /// Pushes a controller onto the navigation stack, or uses fallback if no `UINavigationController` is found.
    /// - Parameter navigation: UINavigationController to push in.
    /// - Returns: NavigationStrategy.
    static func push(navigation: ((UINavigationController) -> Void)? = nil) -> NavigationStrategy {
        PushNavigationStrategy(navigation: navigation)
    }

    /// Presents a controller based on source.
    static func present(source: PresentNavigationSource = .topController) -> NavigationStrategy {
        PresentNavigationStrategy(source: source)
    }

    /// Presents a popover.
    static func popover(configure: @escaping (_ popover: UIPopoverPresentationController, _ controller: UIViewController) -> Void) -> NavigationStrategy {
        PopoverNavigationStrategy(configure: configure)
    }

    /// Close the controller if it is top one
    static func closeIfTop(
        tryToPop: Bool = true,
        tryToDismiss: Bool = true,
        navigation: ((UINavigationController) -> Void)? = nil
    ) -> NavigationStrategy {
        CloseIfTopNavigationStrategy(
            tryToPop: tryToPop,
            tryToDismiss: tryToDismiss,
            navigation: navigation
        )
    }

    /// Replaces `UIWindow`'s `rootViewController` with the given `transition`.
    static func replaceWindowRoot(transition: CATransition? = nil) -> NavigationStrategy {
        ReplaceWindowRootNavigationStrategy(transition: transition)
    }

    /// Pops to existing controller, or uses fallback if no `UINavigationController` is found.
    static func popToExisting(includingTabs: Bool = true) -> NavigationStrategy {
        PopToExistingNavigationStrategy(includingTabs: includingTabs)
    }

    /// Shows in a `UISplitViewController` with the given `strategy`.
    @available (iOS 14.0, *)
    static func split(strategy: SplitStrategy) -> NavigationStrategy {
        SplitNavigationStrategy(strategy: strategy)
    }
}

/// Navigation strategy for `UISplitViewController`.
@available (iOS 14.0, *)
public enum SplitStrategy: Equatable {
    public enum SplitActon: Equatable {
        /// Pushes the selected view controller in `UISplitViewController`.
        case push
        /// Pops to the selected view controller in `UISplitViewController`.
        case pop
        /// Replaces with the selected view controller in `UISplitViewController`.
        case replace
    }

    /// Performs action on the primary view controller in `UISplitViewController`.
    case primary(action: SplitActon)
    /// Performs action on the secondary view controller in `UISplitViewController`.
    case secondary(action: SplitActon)
}

@available(iOS 14.0, *)
class SplitNavigationStrategy: NavigationStrategy {
    let strategy: SplitStrategy

    init(strategy: SplitStrategy) {
        self.strategy = strategy
    }

    override func isEqual(to other: NavigationStrategy?) -> Bool {
        guard let other = other as? Self else {
            return false
        }

        return strategy == other.strategy
    }
}

class PopoverNavigationStrategy: NavigationStrategy {
    let configure: (_ popover: UIPopoverPresentationController, _ controller: UIViewController) -> Void
    
    init(configure: @escaping (_ popover: UIPopoverPresentationController, _ controller: UIViewController) -> Void) {
        self.configure = configure
    }
}

class CloseToExistingNavigationStrategy: NavigationStrategy {}

class RemoveFromStackNavigationStrategy: NavigationStrategy {}

public enum PresentNavigationSource: Sendable, Equatable {
    case topController
    case navigationController
    case tabBarController
}

class PresentNavigationStrategy: NavigationStrategy {
    let source: PresentNavigationSource

    init(source: PresentNavigationSource) {
        self.source = source
    }

    override func isEqual(to other: NavigationStrategy?) -> Bool {
        guard let other = other as? Self else {
            return false
        }

        return source == other.source
    }
}

class ReplaceNavigationRootNavigationStrategy: NavigationStrategy {}

class PopToExistingNavigationStrategy: NavigationStrategy {
    let includingTabs: Bool

    init(includingTabs: Bool) {
        self.includingTabs = includingTabs
    }

    override func isEqual(to other: NavigationStrategy?) -> Bool {
        guard let other = other as? Self else {
            return false
        }

        return includingTabs == other.includingTabs
    }
}

class PushNavigationStrategy: NavigationStrategy {
    let navigation: ((UINavigationController) -> Void)?

    init(navigation: ((UINavigationController) -> Void)?) {
        self.navigation = navigation
    }
}

class ReplaceWindowRootNavigationStrategy: NavigationStrategy {
    let transition: CATransition?

    init(transition: CATransition? = nil) {
        self.transition = transition
    }

    override func isEqual(to other: NavigationStrategy?) -> Bool {
        guard let other = other as? Self else {
            return false
        }

        return transition == other.transition
    }
}

class CloseIfTopNavigationStrategy: NavigationStrategy {
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
    }

    override func isEqual(to other: NavigationStrategy?) -> Bool {
        guard let other = other as? Self else {
            return false
        }

        return tryToDismiss == other.tryToDismiss && tryToPop == other.tryToPop
    }
}
