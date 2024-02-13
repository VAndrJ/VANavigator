//
//  AuthorizationService.swift
//  SimpleExample
//
//  Created by VAndrJ on 13.02.2024.
//

import Foundation

final class ExampleAuthorizationService {
    var onAuthorizationChanged: ((_ isAuthorized: Bool) -> Void)?
    var isAuthorized: Bool { _isAuthorized }

    private var _isAuthorized = false {
        didSet { onAuthorizationChanged?(_isAuthorized) }
    }

    func authorize() {
        _isAuthorized = true
    }
}
