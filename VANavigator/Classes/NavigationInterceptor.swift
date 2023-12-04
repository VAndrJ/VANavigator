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
    var onInterceptionResolved: ((AnyHashable) -> Void)?

    open func intercept(destination: NavigationDestination) -> NavigationInterceptionResult? {
        nil
    }

    public func interceptionResolved(reason: AnyHashable) {
        onInterceptionResolved?(reason)
    }
}

struct InterceptionDetail {
    let chain: [(destination: NavigationDestination, strategy: NavigationStrategy, animated: Bool)]
    let source: NavigationIdentity?
    let event: ResponderEvent?
    let completion: (() -> Void)?
}
