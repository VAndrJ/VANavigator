//
//  NavigatorScreenFactory.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

/// A protocol that defines a factory responsible for assembling view controllers for navigation.
///
/// Conforming types must implement a method to create and return a `UIViewController` based on the provided identity and navigator.
/// This protocol is restricted to the `@MainActor` to ensure all UI-related operations are performed on the main thread.
@MainActor
public protocol NavigatorScreenFactory {

    /// Assembles and returns a view controller for the given navigation identity.
    /// - Parameters:
    ///   - identity: The identity of the screen to assemble.
    ///   - navigator: The navigator responsible for handling navigation actions.
    /// - Returns: A fully assembled `UIViewController` instance.
    func assembleScreen(identity: any NavigationIdentity, navigator: Navigator) -> UIViewController
}
