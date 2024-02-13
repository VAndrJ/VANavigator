//
//  NavigationIdentity+SimpleExample.swift
//  SimpleExample
//
//  Created by VAndrJ on 13.02.2024.
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

struct TabPresentExampleNavigationIdentity: DefaultNavigationIdentity {}

struct QueueNavigationIdentity: DefaultNavigationIdentity {}

struct PrimaryNavigationIdentity: DefaultNavigationIdentity {}

struct SecondaryNavigationIdentity: DefaultNavigationIdentity {}

struct NavNavigationIdentity: NavigationIdentity {
    var children: [NavigationIdentity]

    func isEqual(to other: NavigationIdentity?) -> Bool {
        guard let other = other as? Self else {
            return false
        }
        guard children.count == other.children.count else {
            return false
        }

        for pair in zip(children, other.children) where !pair.0.isEqual(to: pair.1) {
            return false
        }

        return true
    }
}

struct SplitNavigationIdentity: NavigationIdentity {
    var primary: NavigationIdentity
    var secondary: NavigationIdentity
    var supplementary: NavigationIdentity?

    func isEqual(to other: NavigationIdentity?) -> Bool {
        guard let other = other as? Self else {
            return false
        }

        return primary.isEqual(to: other.primary) &&
        secondary.isEqual(to: other.secondary) &&
        supplementary?.isEqual(to: other.supplementary) == true
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
    var children: [NavigationIdentity]

    func isEqual(to other: NavigationIdentity?) -> Bool {
        guard let other = other as? Self else {
            return false
        }
        guard children.count == other.children.count else {
            return false
        }

        for pair in zip(children, other.children) where !pair.0.isEqual(to: pair.1) {
            return false
        }

        return true
    }
}
