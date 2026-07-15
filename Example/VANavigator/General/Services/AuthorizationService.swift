//
//  AuthorizationService.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 04.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Observation

@Observable
@MainActor
final class AuthorizationService {
    var onAuthorized: (() -> Void)?

    private(set) var isAuthorized = false {
        didSet {
            if isAuthorized {
                onAuthorized?()
            }
        }
    }

    func authorize() {
        isAuthorized = true
    }
}
