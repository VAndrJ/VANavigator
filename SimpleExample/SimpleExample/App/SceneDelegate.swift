//
//  SceneDelegate.swift
//  SimpleExample
//
//  Created by VAndrJ on 14.07.2026.
//

import UIKit

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

        let window = UIWindow(windowScene: windowScene)
        self.window = window
        self.compositionRoot = CompositionRoot(window: window)

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
