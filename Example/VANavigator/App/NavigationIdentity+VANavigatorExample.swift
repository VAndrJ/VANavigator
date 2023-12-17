//
//  NavigationIdentity+VANavigatorExample.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Foundation

protocol DefaultNavigationIdentity: NavigationIdentity {}

extension DefaultNavigationIdentity {

    func isEqual(to other: NavigationIdentity?) -> Bool {
        guard other is Self else {
            return false
        }

        return true
    }
}

protocol LoginedOnlyNavigationIdentity: DefaultNavigationIdentity {}

// MARK: - Identities

struct SecretInformationIdentity: LoginedOnlyNavigationIdentity {}

struct LoginNavigationIdentity: DefaultNavigationIdentity {}

struct MainNavigationIdentity: DefaultNavigationIdentity {}

struct TabDetailNavigationIdentity: DefaultNavigationIdentity {}

struct MoreNavigationIdentity: DefaultNavigationIdentity {}

struct PrimaryNavigationIdentity: DefaultNavigationIdentity {}

struct SecondaryNavigationIdentity: DefaultNavigationIdentity {}

struct NavNavigationIdentity: NavigationIdentity {
    var childrenIdentity: [NavigationIdentity]

    func isEqual(to other: NavigationIdentity?) -> Bool {
        guard let other = other as? Self else {
            return false
        }
        guard childrenIdentity.count == other.childrenIdentity.count else {
            return false
        }

        for pair in zip(childrenIdentity, other.childrenIdentity) {
            if !pair.0.isEqual(to: pair.1) {
                return false
            }
        }

        return true
    }
}

struct SplitNavigationIdentity: NavigationIdentity {
    var tabsIdentity: [NavigationIdentity]

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

struct DetailsNavigationIdentity: NavigationIdentity {
    let number: Int

    func isEqual(to other: NavigationIdentity?) -> Bool {
        guard let other = other as? Self else {
            return false
        }

        return number == other.number
    }
}

struct TabNavigationIdentity: NavigationIdentity {
    var tabsIdentity: [NavigationIdentity]

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
