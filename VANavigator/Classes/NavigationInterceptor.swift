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
    private var interceptionData: [AnyHashable: [InterceptedNavigation]] = [:]

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
        removeReleasedNavigators()
        guard let storedDetails = interceptionData.removeValue(forKey: reason) else {
            completion?(nil, false)

            return
        }

        let details = storedDetails.compactMap { detail in
            detail.navigator.map { (detail, $0) }
        }
        guard !details.isEmpty else {
            completion?(nil, false)

            return
        }

        if let newStrategy {
            for (detail, _) in details where !detail.chain.isEmpty {
                detail.chain[0].update(strategy: newStrategy)
            }
        }

        let completionCoordinator = completion.map {
            InterceptionResolutionCompletion(count: details.count, completion: $0)
        }
        for (index, item) in details.enumerated() {
            let (detail, navigator) = item
            let isFirst = index == details.startIndex
            let isLast = index == details.index(before: details.endIndex)
            navigator.navigate(
                chain: (isFirst ? prefixNavigationChain : [])
                    + detail.chain
                    + (isLast ? suffixNavigationChain : []),
                event: detail.event,
                completion: completionCoordinator.map { coordinator in
                    { controller, isSuccess in
                        coordinator.complete(
                            index: index,
                            controller: controller,
                            isSuccess: isSuccess
                        )
                    }
                }
            )
        }
    }

    public func getInterceptionReasons() -> [AnyHashable] {
        removeReleasedNavigators()

        return Array(interceptionData.keys)
    }

    public func removeIfAvailable(reason: AnyHashable) {
        interceptionData.removeValue(forKey: reason)
    }

    public func removeAllReasons() {
        interceptionData.removeAll()
    }

    public func checkIsExists(reason: AnyHashable) -> Bool {
        removeReleasedNavigators()

        return interceptionData[reason] != nil
    }

    func store(_ navigation: InterceptedNavigation, reason: AnyHashable) {
        removeReleasedNavigators()
        interceptionData[reason, default: []].append(navigation)
    }

    func removeNavigations(for navigator: Navigator) {
        interceptionData = interceptionData.reduce(into: [:]) { result, item in
            let activeNavigations = item.value.filter { $0.navigator !== navigator && $0.navigator != nil }
            if !activeNavigations.isEmpty {
                result[item.key] = activeNavigations
            }
        }
    }

    private func removeReleasedNavigators() {
        interceptionData = interceptionData.reduce(into: [:]) { result, item in
            let activeNavigations = item.value.filter { $0.navigator != nil }
            if !activeNavigations.isEmpty {
                result[item.key] = activeNavigations
            }
        }
    }
}

final class InterceptedNavigation {
    var chain: [NavigationChainLink]
    let event: (any ResponderEvent)?
    weak var navigator: Navigator?

    init(
        chain: [NavigationChainLink],
        event: (any ResponderEvent)? = nil,
        navigator: Navigator? = nil
    ) {
        self.chain = chain
        self.event = event
        self.navigator = navigator
    }
}

private final class InterceptionResolutionCompletion {
    private var remainingCount: Int
    private var results: [(UIViewController?, Bool)?]
    private var completion: ((UIViewController?, Bool) -> Void)?

    init(
        count: Int,
        completion: @escaping (UIViewController?, Bool) -> Void
    ) {
        self.remainingCount = count
        self.results = Array(repeating: nil, count: count)
        self.completion = completion
    }

    func complete(
        index: Int,
        controller: UIViewController?,
        isSuccess: Bool
    ) {
        guard case nil = results[index] else { return }

        results[index] = (controller, isSuccess)
        remainingCount -= 1
        guard remainingCount == 0 else { return }

        let result = results.last ?? nil
        let completion = self.completion
        self.completion = nil
        completion?(result?.0, result?.1 ?? false)
    }
}
