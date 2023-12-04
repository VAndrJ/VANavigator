//
//  VAButtonNode+Support.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import VATextureKit

extension VAButtonNode {

    func setTitle(_ title: String, theme: VATheme) {
        setTitle(title, with: nil, with: theme.systemBlue, for: .normal)
        setTitle(title, with: nil, with: theme.systemBlue.withAlphaComponent(0.8), for: .highlighted)
        setTitle(title, with: nil, with: theme.systemGray2, for: .disabled)
    }
}
