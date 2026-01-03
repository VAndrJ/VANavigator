//
//  NavigationInterceptor.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 04.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

/// Represents the result of intercepting a navigation action.
public struct NavigationInterceptionResult {
    public let chain: [NavigationChainLink]
    public let event: (any ResponderEvent)?
    public let reason: AnyHashable

    public init(
        link: NavigationChainLink,
        event: (any ResponderEvent)? = nil,
        reason: AnyHashable
    ) {
        self.chain = [link]
        self.event = event
        self.reason = reason
    }

    public init(
        chain: [NavigationChainLink],
        event: (any ResponderEvent)? = nil,
        reason: AnyHashable
    ) {
        self.chain = chain
        self.event = event
        self.reason = reason
    }
}

/// A class that provides interception capabilities for navigation actions.
@MainActor
open class NavigationInterceptor {
    var onInterceptionResolved:
        (
            (
                _ reason: AnyHashable,
                _ newStrategy: NavigationStrategy?,
                _ prefixNavigationChain: [NavigationChainLink],
                _ suffixNavigationChain: [NavigationChainLink],
                _ completion: ((UIViewController?, Bool) -> Void)?
            ) -> Void
        )?
    var interceptionData: [AnyHashable: InterceptionDetail] = [:]

    public init() {}

    /// Allows subclasses to override this method to intercept a navigation action.
    /// - Parameter destination: The navigation destination being intercepted.
    /// - Returns: An optional interception result; `nil` if no interception occurs.
    open func intercept(destination: NavigationDestination) -> NavigationInterceptionResult? {
        return nil
    }

    /// Resolves an interception by executing the stored closure.
    public func interceptionResolved(
        reason: AnyHashable,
        newStrategy: NavigationStrategy? = nil,
        prefixNavigationChain: [NavigationChainLink] = [],
        suffixNavigationChain: [NavigationChainLink] = [],
        completion: ((UIViewController?, Bool) -> Void)?
    ) {
        onInterceptionResolved?(
            reason,
            newStrategy,
            prefixNavigationChain,
            suffixNavigationChain,
            completion
        )
    }

    public func getInterceptionReasons() -> [AnyHashable] {
        return Array(interceptionData.keys)
    }

    public func removeIfAvailable(reason: AnyHashable) {
        interceptionData.removeValue(forKey: reason)
    }

    public func removeAllReasons() {
        interceptionData.removeAll()
    }

    public func checkIsExists(reason: AnyHashable) -> Bool {
        return interceptionData[reason] != nil
    }
}

class InterceptionDetail {
    var chain: [NavigationChainLink]
    let event: (any ResponderEvent)?
    let completion: ((UIViewController?, Bool) -> Void)?

    init(
        chain: [NavigationChainLink],
        event: (any ResponderEvent)? = nil,
        completion: ((UIViewController?, Bool) -> Void)? = nil
    ) {
        self.chain = chain
        self.event = event
        self.completion = completion
    }
}
