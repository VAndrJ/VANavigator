//
//  AppDelegate.swift
//  VANavigator
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    private var compositionRoot: CompositionRoot?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        self.compositionRoot = CompositionRoot(
            window: &window,
            application: application,
            launchOptions: launchOptions
        )

        return true
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        if let compositionRoot {
            compositionRoot.handleShortcut(item: shortcutItem, completion: completionHandler)
        } else {
            completionHandler(false)
        }
    }
}
