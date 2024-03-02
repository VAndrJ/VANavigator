//
//  CompositionRoot.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import VATextureKit

@MainActor
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
        case .alert:
            navigator.navigate(
                destination: .controller(UIAlertController(
                    title: "Title",
                    message: "Message",
                    preferredStyle: .alert
                ).apply {
                    $0.addAction(UIAlertAction(title: "Close", style: .default))
                }),
                strategy: .present()
            )
        case .main:
            navigator.navigate(
                destination: .identity(MainNavigationIdentity()),
                strategy: .replaceWindowRoot(),
                event: ResponderOpenedFromShortcutEvent()
            )
        case .details:
            let identity = DetailsNavigationIdentity(number: -1)
            navigator.navigate(
                destination: .identity(identity),
                strategy: .popToExisting(),
                fallback: NavigationChainLink(
                    destination: .identity(identity),
                    strategy: .push(),
                    animated: true,
                    fallback: NavigationChainLink(
                        destination: .identity(NavNavigationIdentity(children: [identity])),
                        strategy: .present(),
                        animated: true
                    )
                ),
                event: ResponderOpenedFromShortcutEvent()
            )
        }
        completion(true)
    }
}
