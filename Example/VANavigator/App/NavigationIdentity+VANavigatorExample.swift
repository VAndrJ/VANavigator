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
        guard let other = other as? MainNavigationIdentity else {
            return false
        }

        return true
    }
}
