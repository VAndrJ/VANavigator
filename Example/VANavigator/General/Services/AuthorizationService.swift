//
//  AuthorizationService.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 04.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Observation

@Observable
final class AuthorizationService {
    private(set) var isAuthorized = false

    func authorize() {
        isAuthorized = true
    }
}
