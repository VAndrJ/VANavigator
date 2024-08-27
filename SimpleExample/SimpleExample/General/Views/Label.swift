//
//  Label.swift
//  SimpleExample
//
//  Created by VAndrJ on 8/27/24.
//

import UIKit

class Label: UILabel {

    init(text: String) {
        super.init(frame: .init(x: 0, y: 0, width: 320, height: 20))

        self.text = text
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
