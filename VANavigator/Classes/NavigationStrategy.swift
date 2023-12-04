//
//  NavigationStrategy.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.//

import UIKit

public enum NavigationStrategy: Equatable {
    case replaceWindowRoot(transition: CATransition? = nil)
    case push(alwaysEmbedded: Bool = true)
    case pushOrPopToExisting(alwaysEmbedded: Bool = true)
    case present
    case presentOrCloseToExisting
    case replaceNavigationRoot(alwaysEmbedded: Bool = true)
    case showSplit(strategy: SplitStrategy)

    public enum SplitStrategy: Equatable {
        case replacePrimary
//        case replaceSupplementary
        case replaceSecondary(shouldPop: Bool = true)
        case secondary(shouldPop: Bool = true)
        case replaceSupplementary(shouldPop: Bool = true)
//        case compact
    }
}
