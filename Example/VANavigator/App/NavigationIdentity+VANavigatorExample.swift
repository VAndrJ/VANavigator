//
//  NavigationIdentity+VANavigatorExample.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Foundation

struct MainNavigationIdentity: NavigationIdentity {
    var fallbackSource: NavigationIdentity?

    func isEqual(to other: NavigationIdentity?) -> Bool {
        guard other is Self else {
            return false
        }

        return true
    }
}

struct DetailsNavigationIdentity: NavigationIdentity {
    let number: Int
    var fallbackSource: NavigationIdentity?

    func isEqual(to other: NavigationIdentity?) -> Bool {
        guard let other = other as? Self else {
            return false
        }

        return number == other.number
    }
}

struct TabNavigationIdentity: NavigationIdentity {
    var tabsIdentity: [NavigationIdentity]
    var fallbackSource: NavigationIdentity?

    func isEqual(to other: NavigationIdentity?) -> Bool {
        guard let other = other as? Self else {
            return false
        }
        guard tabsIdentity.count == other.tabsIdentity.count else {
            return false
        }

        for pair in zip(tabsIdentity, other.tabsIdentity) {
            if !pair.0.isEqual(to: pair.1) {
                return false
            }
        }

        return true
    }
}

struct TabDetailNavigationIdentity: NavigationIdentity {
    var fallbackSource: NavigationIdentity?

    func isEqual(to other: NavigationIdentity?) -> Bool {
        guard other is Self else {
            return false
        }

        return true
    }
}

struct MoreNavigationIdentity: NavigationIdentity {
    var fallbackSource: NavigationIdentity?

    func isEqual(to other: NavigationIdentity?) -> Bool {
        guard other is Self else {
            return false
        }

        return true
    }
}
