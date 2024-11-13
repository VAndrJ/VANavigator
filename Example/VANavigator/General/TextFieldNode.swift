//
//  TextFieldNode.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 17.03.2024.
//  Copyright © 2024 Volodymyr Andriienko. All rights reserved.
//

import VATextureKit

class TextFieldNode: VASizedViewWrapperNode<UITextField>, @unchecked Sendable {

    convenience init() {
        self.init(
            childGetter: {
                let textField = UITextField()
                textField.borderStyle = .roundedRect

                return textField
            },
            sizing: .viewHeight
        )
    }
}
