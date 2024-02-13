//
//  UIStackView+Support.swift
//  SimpleExample
//
//  Created by VAndrJ on 13.02.2024.
//

import UIKit

extension UIStackView {

    func addArrangedSubviews(_ views: UIView...) {
        views.forEach(addArrangedSubview(_:))
    }
}
