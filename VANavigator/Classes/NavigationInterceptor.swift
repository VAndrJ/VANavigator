//
//  NavigationInterceptor.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 04.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Foundation

public struct NavigationInterceptionResult {
    let chain: [(destination: NavigationDestination, strategy: NavigationStrategy, animated: Bool)]
    let source: NavigationIdentity?
    let event: ResponderEvent?
    let reason: AnyHashable

    public init(
        chain: [(destination: NavigationDestination, strategy: NavigationStrategy, animated: Bool)],
        source: NavigationIdentity? = nil,
        event: ResponderEvent? = nil,
        reason: AnyHashable
    ) {
        self.chain = chain
        self.source = source
        self.event = event
        self.reason = reason
    }
}

open class NavigationInterceptor {
    var onInterceptionResolved: ((
        _ reason: AnyHashable,
        _ newStrategy: NavigationStrategy?,
        _ prefixNavigationChain: [(destination: NavigationDestination, strategy: NavigationStrategy, animated: Bool)],
        _ suffixNavigationChain: [(destination: NavigationDestination, strategy: NavigationStrategy, animated: Bool)],
        _ completion: (() -> Void)?
    ) -> Void)?
    var interceptionData: [AnyHashable: InterceptionDetail] = [:]

    public init() {}

    open func intercept(destination: NavigationDestination) -> NavigationInterceptionResult? {
        nil
    }

    public func interceptionResolved(
        reason: AnyHashable,
        newStrategy: NavigationStrategy? = nil,
        prefixNavigationChain: [(destination: NavigationDestination, strategy: NavigationStrategy, animated: Bool)] = [],
        suffixNavigationChain: [(destination: NavigationDestination, strategy: NavigationStrategy, animated: Bool)] = [],
        completion: (() -> Void)?
    ) {
        onInterceptionResolved?(reason, newStrategy, prefixNavigationChain, suffixNavigationChain, completion)
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
    var chain: [(destination: NavigationDestination, strategy: NavigationStrategy, animated: Bool)]
    let source: NavigationIdentity?
    let event: ResponderEvent?

    init(
        chain: [(destination: NavigationDestination, strategy: NavigationStrategy, animated: Bool)],
        source: NavigationIdentity? = nil,
        event: ResponderEvent? = nil
    ) {
        self.chain = chain
        self.source = source
        self.event = event
    }
}
