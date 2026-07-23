//
//  NavigationIdentities.swift
//  VANavigator_ExampleTests
//

import VANavigator

protocol DefaultNavigationIdentity: NavigationIdentity {}

extension DefaultNavigationIdentity {
    func isEqual(to other: (any NavigationIdentity)?) -> Bool {
        other is Self
    }
}

protocol LoginedOnlyNavigationIdentity: DefaultNavigationIdentity {}

struct SecretInformationIdentity: LoginedOnlyNavigationIdentity {}

struct LoginNavigationIdentity: DefaultNavigationIdentity {}

struct MainNavigationIdentity: DefaultNavigationIdentity {}

struct MoreNavigationIdentity: DefaultNavigationIdentity {}

struct PrimaryNavigationIdentity: DefaultNavigationIdentity {}

struct SecondaryNavigationIdentity: DefaultNavigationIdentity {}

struct SplitNavigationIdentity: NavigationIdentity {
    var primary: any NavigationIdentity
    var secondary: any NavigationIdentity
    var supplementary: (any NavigationIdentity)?

    func isEqual(to other: (any NavigationIdentity)?) -> Bool {
        guard let other = other as? Self else {
            return false
        }

        let isSupplementaryEqual: Bool
        switch (supplementary, other.supplementary) {
        case (nil, nil):
            isSupplementaryEqual = true
        case let (lhs?, rhs?):
            isSupplementaryEqual = lhs.isEqual(to: rhs)
        default:
            isSupplementaryEqual = false
        }

        return primary.isEqual(to: other.primary)
            && secondary.isEqual(to: other.secondary)
            && isSupplementaryEqual
    }
}
