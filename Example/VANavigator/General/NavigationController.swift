//
//  NavigationController.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import VATextureKit
import VANavigator

final class NavigationController: VANavigationController, Responder {
    var onDismissed: (() -> Void)?

    convenience init(controller: UIViewController) {
        self.init()

        setViewControllers(
            [controller],
            animated: false
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if isBeingDismissed || isMovingFromParentViewController {
            onDismissed?()
        }
    }

    override func configureTheme(_ theme: VATheme) {
        super.configureTheme(theme)

        view.backgroundColor = theme.systemBackground
        navigationBar.tintColor = theme.systemBlue
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()

        if !viewControllers.isEmpty {
            for i in viewControllers.indices.dropLast(1).reversed() where (viewControllers[i] as? NavigationClosable)?.isNotImportant == true {
                viewControllers.remove(at: i)
                if i >= 1 && i < viewControllers.count {
                    (viewControllers[i - 1] as? Responder)?.nextEventResponder = viewControllers[i] as? Responder
                } else if i < 1 && i < viewControllers.count {
                    nextEventResponder = viewControllers[i] as? Responder
                }
            }
        }
    }

    // MARK: - Responder

    var nextEventResponder: Responder? {
        get { topViewController as? Responder }
        set {} // swiftlint:disable:this unused_setter_value
    }

    func handle(event: ResponderEvent) async -> Bool {
        logResponder(from: self, event: event)

        return await nextEventResponder?.handle(event: event) ?? false
    }
}
