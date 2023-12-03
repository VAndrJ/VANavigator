//
//  CompositionRoot.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit
import VANavigator

class CompositionRoot {
    private weak var window: UIWindow?
    private let navigator: Navigator

    init(
        window: inout UIWindow?,
        application: UIApplication,
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) {
        window = UIWindow()
        self.navigator = Navigator(
            window: window,
            screenFactory: ScreenFactory()
        )
        self.window = window

        navigator.navigate(
            destination: .identity(MainNavigationIdentity()),
            strategy: .replaceWindowRoot()
        )
    }
}
