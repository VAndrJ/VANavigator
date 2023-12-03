//
//  NavigatorScreenFactory.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

protocol NavigatorScreenFactory {

    func assembleScreen(identity: NavigationIdentity, navigator: Navigator) -> UIViewController
    func embedInNavigationControllerIfNeeded(controller: UIViewController) -> UIViewController
}
