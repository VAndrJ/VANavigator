//
//  UIEdgeInsets+Support.swift
//  SimpleExample
//
//  Created by VAndrJ on 08.03.2024.
//

import UIKit

extension UIEdgeInsets {

    init(all: CGFloat) {
        self.init(
            top: all,
            left: all,
            bottom: all,
            right: all
        )
    }
}
