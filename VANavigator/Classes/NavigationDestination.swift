//
//  NavigationDestination.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 04.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

/// An enum representing a navigation destination within a navigation flow.
/// A destination can either be identified by a `NavigationIdentity` or represented directly by a `UIViewController`.
public enum NavigationDestination {
    /// Indicates a destination identified by a `NavigationIdentity` and constructed using a screen factory.
    case identity(any NavigationIdentity)
    /// Indicates a destination represented by a specific view controller.
    /// Set the corresponding `NavigationIdentity` when identity-based lookup is required.
    case controller(UIViewController)

    /// Computed property to extract the navigation identity from the destination.
    public var identity: (any NavigationIdentity)? {
        switch self {
        case let .identity(identity):
            return identity
        case let .controller(controller):
            return controller.navigationIdentity
        }
    }

    public func isEqual(to other: NavigationDestination?) -> Bool {
        guard let other else {
            return false
        }

        switch (self, other) {
        case let (.identity(lhs), .identity(rhs)):
            return lhs.isEqual(to: rhs)
        case let (.controller(lhs), .controller(rhs)):
            return lhs === rhs
        case let (.identity(lhs), .controller(rhs)):
            return lhs.isEqual(to: rhs.navigationIdentity)
        case let (.controller(lhs), .identity(rhs)):
            return rhs.isEqual(to: lhs.navigationIdentity)
        }
    }
}
