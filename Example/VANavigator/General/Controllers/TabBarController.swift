//
//  TabBarController.swift
//  VANavigator
//
//  Created by VAndrJ on 15.07.2026.
//  Copyright © 2026 Volodymyr Andriienko. All rights reserved.
//

import UIKit

final class TabBarController: UITabBarController {
    init(controllers: [UIViewController]) {
        super.init(nibName: nil, bundle: nil)

        setViewControllers(
            controllers,
            animated: false
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
