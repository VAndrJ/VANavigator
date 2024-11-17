//
//  ButtonNode.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 17.03.2024.
//  Copyright © 2024 Volodymyr Andriienko. All rights reserved.
//

import RxSwift
import RxCocoa
import VATextureKitRx

class ButtonNode: VAButtonNode, @unchecked Sendable {
    let bag = DisposeBag()

    convenience init(isEnabledObs: Observable<Bool>) {
        self.init()

        isEnabledObs
            .bind(to: super.rx.isEnabled)
            .disposed(by: bag)
    }
}
