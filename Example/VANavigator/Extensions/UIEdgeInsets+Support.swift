//
//  UIEdgeInsets+Support.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 15.07.2026.
//  Copyright © 2026 Volodymyr Andriienko. All rights reserved.
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
