//
//  NavigationInterceptor.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 04.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

public struct NavigationInterceptionResult {
    let chain: [NavigationChainLink]
    let event: ResponderEvent?
    let reason: AnyHashable

    public init(
        link: NavigationChainLink,
        event: ResponderEvent? = nil,
        reason: AnyHashable
    ) {
        self.chain = [link]
        self.event = event
        self.reason = reason
    }

    public init(
        chain: [NavigationChainLink],
        event: ResponderEvent? = nil,
        reason: AnyHashable
    ) {
        self.chain = chain
        self.event = event
        self.reason = reason
    }
}

@MainActor
open class NavigationInterceptor {
    var onInterceptionResolved: ((
        _ reason: AnyHashable,
        _ newStrategy: NavigationStrategy?,
        _ prefixNavigationChain: [NavigationChainLink],
        _ suffixNavigationChain: [NavigationChainLink],
        _ completion: ((UIViewController?, Bool) -> Void)?
    ) -> Void)?
    var interceptionData: [AnyHashable: InterceptionDetail] = [:]

    public init() {}

    open func intercept(destination: NavigationDestination) -> NavigationInterceptionResult? {
        nil
    }

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
        Array(interceptionData.keys)
    }

    public func removeIfAvailable(reason: AnyHashable) {
        interceptionData.removeValue(forKey: reason)
    }

    public func removeAllReasons() {
        interceptionData.removeAll()
    }

    public func checkIsExists(reason: AnyHashable) -> Bool {
        interceptionData[reason] != nil
    }
}

class InterceptionDetail {
    var chain: [NavigationChainLink]
    let event: ResponderEvent?
    let completion: ((UIViewController?, Bool) -> Void)?

    init(
        chain: [NavigationChainLink],
        event: ResponderEvent? = nil,
        completion: ((UIViewController?, Bool) -> Void)? = nil
    ) {
        self.chain = chain
        self.event = event
        self.completion = completion
    }
}
