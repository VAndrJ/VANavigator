//
//  NavigatorScreenFactory.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

@MainActor
public protocol NavigatorScreenFactory {

    func assembleScreen(identity: any NavigationIdentity, navigator: Navigator) -> UIViewController
}
