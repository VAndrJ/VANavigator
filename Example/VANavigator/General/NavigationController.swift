//
//  NavigationController.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import VATextureKit

final class NavigationController: VANavigationController, Responder {
    var onDismissed: (() -> Void)?

    convenience init(controllers: [UIViewController]) {
        self.init(nibName: nil, bundle: nil)

        setViewControllers(
            controllers,
            animated: false
        )
    }

    convenience init(controller: UIViewController) {
        self.init(nibName: nil, bundle: nil)

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

        if isBeingDismissed || isMovingFromParent {
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
            for i in viewControllers.indices.dropLast(1).reversed() where (viewControllers[i] as? (any NavigationClosable))?.isNotImportant == true {
                viewControllers.remove(at: i)
                if i >= 1 && i < viewControllers.count {
                    (viewControllers[i - 1] as? (any Responder))?.nextEventResponder = viewControllers[i] as? (any Responder)
                } else if i < 1 && i < viewControllers.count {
                    nextEventResponder = viewControllers[i] as? (any Responder)
                }
            }
        }
    }

    // MARK: - Responder

    var nextEventResponder: (any Responder)? {
        get { topViewController as? (any Responder) }
        set {} // swiftlint:disable:this unused_setter_value
    }

    func handle(event: any ResponderEvent) async -> Bool {
        logResponder(from: self, event: event)

        return await nextEventResponder?.handle(event: event) ?? false
    }
}
