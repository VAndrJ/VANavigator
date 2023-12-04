//
//  UIViewController+Navigator.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

extension UIViewController {
    public var orNavigationController: UINavigationController? { (self as? UINavigationController) ?? navigationController }
    public var orTabBarController: UITabBarController? { (self as? UITabBarController) ?? tabBarController }
    
    func topViewController(in rootViewController: UIViewController? = nil, root: Bool = false) -> UIViewController? {
        let currentController = root ? self : rootViewController
        guard let controller = currentController else {
            return nil
        }
        
        var possibleController: UIViewController?
        if let tabBarController = controller as? UITabBarController {
            possibleController = tabBarController.selectedViewController
        } else if let navigationController = controller as? UINavigationController {
            possibleController = navigationController.topViewController
        } else if let splitController = controller as? UISplitViewController {
            possibleController = splitController.viewControllers.last
        } else if let presentedViewController = controller.presentedViewController {
            possibleController = presentedViewController
        }

        if let possibleController, !possibleController.isBeingDismissed {
            return topViewController(in: possibleController)
        } else {
            return controller
        }
    }
    
    func findController(controller: UIViewController) -> UIViewController? {
        if self === controller {
            return self
        } else if let navigation = self as? UINavigationController {
            for controller in navigation.viewControllers {
                if let target = controller.findController(controller: controller) {
                    return target
                }
            }
        } else if let tab = self as? UITabBarController {
            for controller in (tab.viewControllers ?? []) {
                if let target = controller.findController(controller: controller) {
                    return target
                }
            }
        } else if let split = self as? UISplitViewController {
            for controller in split.viewControllers {
                if let target = controller.findController(controller: controller) {
                    return target
                }
            }
        } else if let presentedViewController {
            return presentedViewController.findController(controller: controller)
        }

        return nil
    }
    
    func findController(identity: NavigationIdentity) -> UIViewController? {
        if navigationIdentity?.isEqual(to: identity) == true {
            return self
        } else if let navigation = self as? UINavigationController {
            for controller in navigation.viewControllers {
                if let target = controller.findController(identity: identity) {
                    return target
                }
            }
        } else if let tab = self as? UITabBarController {
            for controller in (tab.viewControllers ?? []) {
                if let target = controller.findController(identity: identity) {
                    return target
                }
            }
        } else if let presentedViewController {
            return presentedViewController.findController(identity: identity)
        } else if let split = self as? UISplitViewController {
            for controller in split.viewControllers {
                if let target = controller.findController(identity: identity) {
                    return target
                }
            }
        }

        return nil
    }
    
    func findTabBarController() -> UITabBarController? {
        if let tabController = self as? UITabBarController {
            return tabController
        } else if let tabBarController {
            return tabBarController
        } else if let presentingViewController {
            return presentingViewController.findTabBarController()
        } else {
            return nil
        }
    }
    
    func findController(destination: NavigationDestination) -> UIViewController? {
        switch destination {
        case let .identity(identity):
            return findController(identity: identity)
        case let .controller(controller):
            return findController(controller: controller)
        }
    }
    
    public var navigationIdentity: (any NavigationIdentity)? {
        get { (objc_getAssociatedObject(self, &navigationIdentityKey) as? (any NavigationIdentity)) }
        set { objc_setAssociatedObject(self, &navigationIdentityKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

extension UISplitViewController {
    var isSingleNavigation: Bool { viewControllers.count == 1 && viewControllers.first is UINavigationController }
}

private var navigationIdentityKey = "com.vandrj.navigationIdentityKey"
