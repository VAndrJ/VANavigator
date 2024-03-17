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

    @MainActor
    override func isFirstResponder() -> Bool {
        child.isFirstResponder
    }

    @discardableResult
    @MainActor
    override func becomeFirstResponder() -> Bool {
        child.becomeFirstResponder()
    }

    @discardableResult
    @MainActor
    override func resignFirstResponder() -> Bool {
        child.resignFirstResponder()
    }
}
