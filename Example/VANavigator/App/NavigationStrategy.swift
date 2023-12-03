//
//  NavigationStrategy.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

public enum NavigationStrategy: Equatable {
    case replaceWindowRoot(transition: CATransition? = nil)
    case push(alwaysEmbedded: Bool = true)
    case pushOrPopToExisting(alwaysEmbedded: Bool = true)
    case present
    case presentOrCloseToExisting
    case replaceNavigationRoot
}
