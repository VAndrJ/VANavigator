//
//  NavigationDestination.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 04.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

public enum NavigationDestination {
    case identity(NavigationIdentity)
    case controller(UIViewController)

    /// Computed property to extract the navigation identity from the destination.
    var identity: NavigationIdentity? {
        switch self {
        case let .identity(identity):
            return identity
        case let .controller(controller):
            return controller.navigationIdentity
        }
    }
}
