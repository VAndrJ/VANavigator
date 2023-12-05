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
    let completion: (() -> Void)?
    let reason: AnyHashable

    public init(
        chain: [(destination: NavigationDestination, strategy: NavigationStrategy, animated: Bool)],
        source: NavigationIdentity? = nil,
        event: ResponderEvent? = nil,
        completion: (() -> Void)? = nil,
        reason: AnyHashable
    ) {
        self.chain = chain
        self.source = source
        self.event = event
        self.completion = completion
        self.reason = reason
    }
}

open class NavigationInterceptor {
    var onInterceptionResolved: ((AnyHashable, NavigationStrategy?) -> Void)?
    var interceptionData: [AnyHashable: InterceptionDetail] = [:]

    public init() {}

    open func intercept(destination: NavigationDestination) -> NavigationInterceptionResult? {
        nil
    }

    public func interceptionResolved(reason: AnyHashable, newStrategy: NavigationStrategy? = nil) {
        onInterceptionResolved?(reason, newStrategy)
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
    let completion: (() -> Void)?

    init(
        chain: [(destination: NavigationDestination, strategy: NavigationStrategy, animated: Bool)],
        source: NavigationIdentity? = nil,
        event: ResponderEvent? = nil,
        completion: (() -> Void)? = nil
    ) {
        self.chain = chain
        self.source = source
        self.event = event
        self.completion = completion
    }
}
