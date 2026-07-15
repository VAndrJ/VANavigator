//
//  Button.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 15.07.2026.
//  Copyright © 2026 Volodymyr Andriienko. All rights reserved.
//

import UIKit

class Button: UIButton {
    var onTap: (() -> Void)?

    init(title: String) {
        super.init(frame: .init(x: 0, y: 0, width: 44, height: 44))

        bind()
        setTitle(title, for: .normal)
        if #available(iOS 15.0, *) {
            configuration = .plain()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func bind() {
        addAction(
            UIAction(handler: self ?> { $0.onTap?() }),
            for: .touchUpInside
        )
    }
}
