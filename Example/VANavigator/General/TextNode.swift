//
//  TextNode.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 17.03.2024.
//  Copyright © 2024 Volodymyr Andriienko. All rights reserved.
//

import VATextureKitRx

class TextNode: VATextNode {
    let bag = DisposeBag()

    convenience init(
        textObs: Observable<String>,
        fontStyle: VAFontStyle = .body,
        kern: VAKern? = nil,
        lineHeight: VALineHeight? = nil,
        alignment: NSTextAlignment = .natural,
        truncationMode: NSLineBreakMode = .byWordWrapping,
        maximumNumberOfLines: UInt? = .none,
        colorGetter: @escaping (VATheme) -> UIColor = { $0.label },
        secondary: [SecondaryAttributes]? = nil
    ) {
        self.init(
            text: nil,
            fontStyle: fontStyle,
            kern: kern,
            lineHeight: lineHeight,
            alignment: alignment,
            truncationMode: truncationMode,
            maximumNumberOfLines: maximumNumberOfLines,
            colorGetter: colorGetter,
            secondary: secondary
        )

        textObs
            .bind(to: super.rx.text)
            .disposed(by: bag)
    }
}
