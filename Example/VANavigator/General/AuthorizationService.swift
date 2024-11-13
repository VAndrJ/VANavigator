//
//  AuthorizationService.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 04.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import RxSwift
import VATextureKitRx

class AuthorizationService {
    @Obs.Relay(value: false)
    var isAuthorizedObs: Observable<Bool>
    var isAuthorized: Bool { _isAuthorizedObs.value }

    func authorize() {
        _isAuthorizedObs.rx.accept(true)
    }
}
