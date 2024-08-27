//
//  TextFieldNode.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 17.03.2024.
//  Copyright © 2024 Volodymyr Andriienko. All rights reserved.
//

import VATextureKit

class TextFieldNode: VASizedViewWrapperNode<UITextField> {

    convenience init() {
        self.init(
            actorChildGetter: {
                let textField = UITextField()
                textField.borderStyle = .roundedRect

                return textField
            },
            sizing: .viewHeight
        )
    }
}
