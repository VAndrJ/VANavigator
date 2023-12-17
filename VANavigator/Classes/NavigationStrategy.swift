//
//  NavigationStrategy.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

public enum NavigationStrategy: Equatable {
    /// Close the controller if it is top one
    case closeIfTop(tryToPop: Bool = true, tryToDismiss: Bool = true)
    /// Replaces `UIWindow`'s `rootViewController` with the given `transition`.
    case replaceWindowRoot(transition: CATransition? = nil)
    /// Pushes a controller onto the navigation stack, or uses fallback if no `UINavigationController` is found.
    case push
    /// Pushes a controller onto the navigation stack, or pops to an existing one, or uses fallback if no `UINavigationController` is found. 
    case popToExisting(includingTabs: Bool = true)
    /// Replaces the navigation stack with the given controller as the root or uses fallback if no `UINavigationController` is found.
    case replaceNavigationRoot
    /// Presents a controller from the top view controller or sets `UIWindow`'s `rootViewController`.
    case present
    /// Closes presented controllers to given controller if it exists.
    case closeToExisting
    /// Shows in a `UISplitViewController` with the given `strategy`.
    case showSplit(strategy: SplitStrategy)

    /// Navigation strategy for `UISplitViewController`.
    public enum SplitStrategy: Equatable {
        /// Replaces the primary view controller in `UISplitViewController`.
        case replacePrimary
        /// Replaces the secondary view controller in `UISplitViewController` or pops to existing based on the `shouldPop` flag.
        case replaceSecondary(shouldPop: Bool = true)
        /// Shows the secondary view controller in `UISplitViewController` or pops to existing based on the `shouldPop` flag.
        case secondary(shouldPop: Bool = true)
        /// Replaces the supplementary view controller in `UISplitViewController` or pops to existing based on the `shouldPop` flag. For styles other than `.tripleColumn`, shows as a secondary controller.
        case replaceSupplementary(shouldPop: Bool = true)
    }
}
