//
//  TabBarController.swift
//  SimpleExample
//
//  Created by VAndrJ on 13.02.2024.
//

import UIKit

class TabBarController: UITabBarController {

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
