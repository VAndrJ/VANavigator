//
//  AppDelegate.swift
//  VANavigator
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    private var compositionRoot: CompositionRoot?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?
    ) -> Bool {
        self.compositionRoot = CompositionRoot(
            window: &window,
            application: application,
            launchOptions: launchOptions
        )

        return true
    }
}
