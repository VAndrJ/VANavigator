//
//  Label.swift
//  VANavigator
//
//  Created by VAndrJ on 15.07.2026.
//  Copyright © 2026 Volodymyr Andriienko. All rights reserved.
//

import UIKit

class Label: UILabel {
    init(text: String = "", textStyle: UIFont.TextStyle) {
        super.init(frame: .init(x: 0, y: 0, width: 320, height: 20))

        self.text = text
        self.font = UIFont.preferredFont(forTextStyle: textStyle)
        self.numberOfLines = 0
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
