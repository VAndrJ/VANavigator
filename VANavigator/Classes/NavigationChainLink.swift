//
//  NavigationChainLink.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 16.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Foundation

@MainActor
public final class NavigationChainLink: Equatable {
    public static func == (lhs: NavigationChainLink, rhs: NavigationChainLink) -> Bool {
        lhs.destination == rhs.destination &&
        lhs.strategy == rhs.strategy &&
        lhs.animated == rhs.animated &&
        lhs.fallback == rhs.fallback
    }

    public let destination: NavigationDestination
    public private(set) var strategy: NavigationStrategy
    public let animated: Bool
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
}
