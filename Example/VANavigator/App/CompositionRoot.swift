//
//  CompositionRoot.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import VATextureKit

class CompositionRoot {
    private weak var window: UIWindow?
    private let navigator: Navigator
    private let shortcutService = ShortcutsService()
    private let authorizationService = AuthorizationService()
    private let navigationInterceptor: ExampleNavigationInterceptor

    init(
        window: inout UIWindow?,
        application: UIApplication,
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) {
        window = VAWindow(
            standardLightTheme: .vaLight,
            standardDarkTheme: .vaDark
        )
        self.navigationInterceptor = ExampleNavigationInterceptor(authorizationService: authorizationService)
        self.navigator = Navigator(
            window: window,
            screenFactory: ScreenFactory(authorizationService: authorizationService),
            navigationInterceptor: navigationInterceptor
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
        case .details:
            navigator.navigate(
                destination: .identity(DetailsNavigationIdentity(number: -1)),
                strategy: .pushOrPopToExisting(),
                event: ResponderOpenedFromShortcutEvent()
            )
        }
        completion(true)
    }
}
