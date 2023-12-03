//
//  CompositionRoot.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import VATextureKit
import VANavigator

class CompositionRoot {
    private weak var window: UIWindow?
    private let navigator: Navigator
    private let shortcutService = ShortcutsService()

    init(
        window: inout UIWindow?,
        application: UIApplication,
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) {
        window = VAWindow(
            standardLightTheme: .vaLight,
            standardDarkTheme: .vaDark
        )
        self.navigator = Navigator(
            window: window,
            screenFactory: ScreenFactory()
        )
        self.window = window

        shortcutService.addShortcuts()

        navigator.navigate(
            destination: .identity(MainNavigationIdentity()),
            strategy: .replaceWindowRoot()
        )
    }

    func handleShortcut(item: UIApplicationShortcutItem, completion: @escaping (Bool) -> Void) {
        guard let shortcut = Shortcut(rawValue: item.type) else {
            completion(false)
            return
        }

        switch shortcut {
        case .main:
            navigator.navigate(
                destination: .identity(MainNavigationIdentity()),
                strategy: .replaceWindowRoot(),
                event: ResponderOpenedFromShortcutEvent()
            )
        }
        completion(true)
    }
}
