//
//  NavigationIdentity.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Foundation

@MainActor
public protocol NavigationIdentity {
    func isEqual(to other: (any NavigationIdentity)?) -> Bool
}
