//
//  NavigationChainLink.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 16.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Foundation

/// A class representing a link in a chain of navigation steps.
@MainActor
public final class NavigationChainLink {
    public let destination: NavigationDestination
    public private(set) var strategy: NavigationStrategy
    public let animated: Bool
    /// An optional fallback navigation link to be used if the current `NavigationDestination` fails.
    /// This allows for a fallback behavior in case the navigation to the primary `destination`
    /// does not succeed.
    public let fallback: NavigationChainLink?

    public init(
        destination: NavigationDestination,
        strategy: NavigationStrategy,
        animated: Bool,
        fallback: NavigationChainLink? = nil
    ) {
        self.destination = destination
        self.strategy = strategy
        self.animated = animated
        self.fallback = fallback
    }

    func update(strategy: NavigationStrategy) {
        self.strategy = strategy
    }

    public func isEqual(to other: NavigationChainLink?) -> Bool {
        guard let other else {
            return false
        }

        return destination.isEqual(to: other.destination)
            && strategy == other.strategy
            && animated == other.animated
            && fallback?.isEqual(to: other.fallback) ?? (fallback == nil && other.fallback == nil)
    }
}
