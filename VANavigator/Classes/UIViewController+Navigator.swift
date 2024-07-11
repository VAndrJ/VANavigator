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
    public var topController: UIViewController {
        var possibleController: UIViewController?
        if let tabBarController = self as? UITabBarController {
            possibleController = tabBarController.selectedViewController
        } else if let navigationController = self as? UINavigationController {
            possibleController = navigationController.topViewController
        } else if let splitController = self as? UISplitViewController {
            possibleController = splitController.viewControllers.last
        } else if let presentedViewController = presentedViewController {
            possibleController = presentedViewController
        }

        if let possibleController, !possibleController.isBeingDismissed {
            return possibleController.topController
        } else {
            return self
        }
    }

    public func findController(
        controller: UIViewController,
        withPresented: Bool
    ) -> UIViewController? {
        if self === controller {
            return self
        } else if let navigation = self as? UINavigationController {
            for child in navigation.viewControllers {
                if let target = child.findController(
                    controller: controller,
                    withPresented: withPresented
                ) {
                    return target
                }
            }
        } else if let tab = self as? UITabBarController {
            for child in (tab.viewControllers ?? []) {
                if let target = child.findController(
                    controller: controller,
                    withPresented: withPresented
                ) {
                    return target
                }
            }
        } else if let split = self as? UISplitViewController {
            for child in split.viewControllers {
                if let target = child.findController(
                    controller: controller,
                    withPresented: withPresented
                ) {
                    return target
                }
            }
        } else if withPresented, let presentedViewController {
            return presentedViewController.findController(
                controller: controller,
                withPresented: withPresented
            )
        }

        return nil
    }

    public func findController(
        identity: any NavigationIdentity,
        withPresented: Bool
    ) -> UIViewController? {
        if navigationIdentity?.isEqual(to: identity) == true {
            return self
        } else if let navigation = self as? UINavigationController {
            for controller in navigation.viewControllers {
                if let target = controller.findController(
                    identity: identity,
                    withPresented: withPresented
                ) {
                    return target
                }
            }
        } else if let tab = self as? UITabBarController {
            for controller in (tab.viewControllers ?? []) {
                if let target = controller.findController(
                    identity: identity,
                    withPresented: withPresented
                ) {
                    return target
                }
            }
        } else if let split = self as? UISplitViewController {
            for controller in split.viewControllers {
                if let target = controller.findController(
                    identity: identity,
                    withPresented: withPresented
                ) {
                    return target
                }
            }
        } else if withPresented, let presentedViewController {
            return presentedViewController.findController(
                identity: identity,
                withPresented: withPresented
            )
        }

        return nil
    }

    public func findTabBarController() -> UITabBarController? {
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
    
    public func findController(
        destination: NavigationDestination,
        withPresented: Bool = false
    ) -> UIViewController? {
        switch destination {
        case let .identity(identity):
            return findController(
                identity: identity,
                withPresented: withPresented
            )
        case let .controller(controller):
            return findController(
                controller: controller,
                withPresented: withPresented
            )
        }
    }
}

public extension UISplitViewController {
    var isSingleNavigation: Bool { viewControllers.count == 1 && viewControllers.first is UINavigationController }
}
