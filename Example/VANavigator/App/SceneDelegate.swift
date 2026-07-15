//
//  SceneDelegate.swift
//  VANavigator
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit
import VATextureKit

@MainActor
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private var compositionRoot: CompositionRoot?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        let window = VAWindow(
            themeManager: VAThemeManager(
                standardLightTheme: .vaLight,
                standardDarkTheme: .vaDark,
                userInterfaceStyle: VAUserInterfaceStyle(
                    userInterfaceStyle: windowScene.traitCollection.userInterfaceStyle
                )
            ),
            windowScene: windowScene
        )

        self.compositionRoot = CompositionRoot(window: window)
        self.window = window

        if let shortcutItem = connectionOptions.shortcutItem {
            handleShortcut(item: shortcutItem)
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        handleShortcut(item: shortcutItem, completion: completionHandler)
    }

    private func handleShortcut(
        item: UIApplicationShortcutItem,
        completion: ((Bool) -> Void)? = nil
    ) {
        if let compositionRoot {
            compositionRoot.handleShortcut(
                item: item,
                completion: { handled in
                    completion?(handled)
                }
            )
        } else {
            completion?(false)
        }
    }
}
