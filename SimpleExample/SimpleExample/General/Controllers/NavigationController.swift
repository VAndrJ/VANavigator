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

//    override func didReceiveMemoryWarning() {
//        super.didReceiveMemoryWarning()
//
//        if !viewControllers.isEmpty {
//            for i in viewControllers.indices.dropLast(1).reversed() where (viewControllers[i] as? NavigationClosable)?.isNotImportant == true {
//                viewControllers.remove(at: i)
//                if i >= 1 && i < viewControllers.count {
//                    (viewControllers[i - 1] as? Responder)?.nextEventResponder = viewControllers[i] as? Responder
//                } else if i < 1 && i < viewControllers.count {
//                    nextEventResponder = viewControllers[i] as? Responder
//                }
//            }
//        }
//    }

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
