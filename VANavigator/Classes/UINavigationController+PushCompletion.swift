//
//  UINavigationController+PushCompletion.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

extension UINavigationController {
    static let completionDelegate = NavigationCompletionDelegate()

    public func pushViewController(
        _ viewController: UIViewController,
        animated: Bool,
        completion: (() -> Void)?
    ) {
        pushViewController(viewController, animated: animated)
        if animated {
            if delegate == nil {
                Self.completionDelegate.completion = { [weak self] in
                    if self?.delegate === Self.completionDelegate {
                        self?.delegate = nil
                    }
                    completion?()
                }
                delegate = Self.completionDelegate
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    completion?()
                }
            }
        } else {
            completion?()
        }
    }
}

class NavigationCompletionDelegate: NSObject, UINavigationControllerDelegate {
    var completion: (() -> Void)?

    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        completion?()
    }
}
