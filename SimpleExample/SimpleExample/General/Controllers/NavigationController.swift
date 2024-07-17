//
//  NavigationController.swift
//  SimpleExample
//
//  Created by VAndrJ on 13.02.2024.
//

import UIKit

final class NavigationController: UINavigationController, Responder {
    var onDismissed: (() -> Void)?

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    init(controller: UIViewController) {
        super.init(nibName: nil, bundle: nil)

        setViewControllers(
            [controller],
            animated: false
        )
    }

    init(controllers: [UIViewController]) {
        super.init(nibName: nil, bundle: nil)

        setViewControllers(
            controllers,
            animated: false
        )
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if isBeingDismissed || isMovingFromParent {
            onDismissed?()
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
