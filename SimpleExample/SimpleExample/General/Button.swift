//
//  Button.swift
//  SimpleExample
//
//  Created by VAndrJ on 13.02.2024.
//

import UIKit

class Button: UIButton {
    var onTap: (() -> Void)?

    init(title: String) {
        super.init(frame: CGRect(x: 0, y: 0, width: 44, height: 44))

        bind()
        setTitle(title, for: .normal)
        if #available(iOS 15.0, *) {
            configuration = .plain()
        }
    }

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 44, height: 44))

        bind()
        if #available(iOS 15.0, *) {
            configuration = .plain()
        }
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func bind() {
        addAction(UIAction(handler: self ?> { $0.onTap?() }), for: .touchUpInside)
    }
}
