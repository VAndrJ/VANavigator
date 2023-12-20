//
//  NavigationStrategy.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

public class NavigationStrategy: Equatable {
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
    /// Pushes a controller onto the navigation stack, or uses fallback if no `UINavigationController` is found.
    static var push: NavigationStrategy { PushNavigationStrategy() }
    /// Replaces the navigation stack with the given controller as the root or uses fallback if no `UINavigationController` is found.
    static var replaceNavigationRoot: NavigationStrategy { ReplaceNavigationRootNavigationStrategy() }
    /// Closes presented controllers to given controller if it exists.
    static var closeToExisting: NavigationStrategy { CloseToExistingNavigationStrategy() }

    /// Presents a controller based on source.
    static func present(source: PresentNavigationSource = .topController) -> NavigationStrategy {
        PresentNavigationStrategy(source: source)
    }

    /// Close the controller if it is top one
    static func closeIfTop(tryToPop: Bool = true, tryToDismiss: Bool = true) -> NavigationStrategy {
        CloseIfTopNavigationStrategy(tryToPop: tryToPop, tryToDismiss: tryToDismiss)
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

class CloseToExistingNavigationStrategy: NavigationStrategy {}

public enum PresentNavigationSource: Equatable {
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

class PushNavigationStrategy: NavigationStrategy {}

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

    init(tryToPop: Bool, tryToDismiss: Bool) {
        self.tryToPop = tryToPop
        self.tryToDismiss = tryToDismiss
    }

    override func isEqual(to other: NavigationStrategy?) -> Bool {
        guard let other = other as? Self else {
            return false
        }

        return tryToDismiss == other.tryToDismiss && tryToPop == other.tryToPop
    }
}
