//
//  NavigationChainLink.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 16.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Foundation

public final class NavigationChainLink {
    let destination: NavigationDestination
    var strategy: NavigationStrategy
    let animated: Bool
    let fallback: NavigationChainLink?

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
}
