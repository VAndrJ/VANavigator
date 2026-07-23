//
//  NumbersTextField.swift
//  VANavigator
//
//  Created by VAndrJ on 15.07.2026.
//  Copyright © 2026 Volodymyr Andriienko. All rights reserved.
//

import UIKit

final class NumbersTextField: UITextField {
    init(onEditingChanged: @escaping ([Int]) -> Void) {
        super.init(frame: .init(x: 0, y: 0, width: 320, height: 32))

        self.onEditingChanged = { text in
            onEditingChanged(
                text.flatMap {
                    $0.components(separatedBy: " ").compactMap { Int($0) }
                } ?? []
            )
        }
        borderStyle = .roundedRect
        delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension NumbersTextField: UITextFieldDelegate {
    private static let numbersSet = CharacterSet(charactersIn: "1234567890 ")

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        return string.unicodeScalars.allSatisfy(Self.numbersSet.contains(_:))
    }
}

extension UITextField {
    var onEditingChanged: ((String?) -> Void)? {
        get { nil }
        set {
            addAction(
                UIAction { [weak self] _ in
                    newValue?(self?.text)
                },
                for: .editingChanged
            )
        }
    }
}
