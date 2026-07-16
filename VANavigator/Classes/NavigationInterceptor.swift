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

        let completionCoordinator = completion.map {
            InterceptionResolutionCompletion(count: details.count, completion: $0)
        }
        for (index, item) in details.enumerated() {
            let (detail, navigator) = item
            let isFirst = index == details.startIndex
            let isLast = index == details.index(before: details.endIndex)
            navigator.navigate(
                chain: (isFirst ? prefixNavigationChain : [])
                    + detail.chain(replacingInitialStrategyWith: newStrategy)
                    + (isLast ? suffixNavigationChain : []),
                event: detail.event,
                completion: { controller, isSuccess in
                    detail.complete(controller: controller, isSuccess: isSuccess)
                    completionCoordinator?.complete(
                        index: index,
                        controller: controller,
                        isSuccess: isSuccess
                    )
                }
            )
        }
    }

    /// Returns the reasons that currently have at least one pending intercepted navigation.
    public func getInterceptionReasons() -> [AnyHashable] {
        removeReleasedNavigators()

        return Array(interceptionData.keys)
    }

    /// Cancels every pending navigation for `reason` and completes each one once with `(nil, false)`.
    public func removeIfAvailable(reason: AnyHashable) {
        let removedNavigations = interceptionData.removeValue(forKey: reason) ?? []
        cancel(removedNavigations)
    }

    /// Cancels all pending intercepted navigations and completes each one once with `(nil, false)`.
    public func removeAllReasons() {
        let removedNavigations = interceptionData.values.flatMap { $0 }
        interceptionData.removeAll()
        cancel(removedNavigations)
    }

    /// Returns whether at least one pending intercepted navigation exists for `reason`.
    public func checkIsExists(reason: AnyHashable) -> Bool {
        removeReleasedNavigators()

        return interceptionData[reason] != nil
    }

    func store(_ navigation: InterceptedNavigation, reason: AnyHashable) {
        removeReleasedNavigators()
        interceptionData[reason, default: []].append(navigation)
    }

    func removeNavigations(for navigator: Navigator) {
        removeNavigations {
            $0.navigator === navigator || $0.navigator == nil
        }
    }

    private func removeReleasedNavigators() {
        removeNavigations { $0.navigator == nil }
    }

    private func removeNavigations(where shouldRemove: (InterceptedNavigation) -> Bool) {
        var activeData: [AnyHashable: [InterceptedNavigation]] = [:]
        var removedNavigations: [InterceptedNavigation] = []
        for (reason, navigations) in interceptionData {
            let activeNavigations = navigations.filter {
                if shouldRemove($0) {
                    removedNavigations.append($0)

                    return false
                }

                return true
            }
            if !activeNavigations.isEmpty {
                activeData[reason] = activeNavigations
            }
        }
        interceptionData = activeData
        cancel(removedNavigations)
    }

    private func cancel(_ navigations: [InterceptedNavigation]) {
        for navigation in navigations {
            navigation.complete(controller: nil, isSuccess: false)
        }
    }
}

final class InterceptedNavigation {
    let chain: [NavigationChainLink]
    let event: (any ResponderEvent)?
    private var completion: ((UIViewController?, Bool) -> Void)?
    weak var navigator: Navigator?

    init(
        chain: [NavigationChainLink],
        event: (any ResponderEvent)? = nil,
        completion: ((UIViewController?, Bool) -> Void)? = nil,
        navigator: Navigator? = nil
    ) {
        self.chain = chain
        self.event = event
        self.completion = completion
        self.navigator = navigator
    }

    func complete(controller: UIViewController?, isSuccess: Bool) {
        guard let completion else { return }

        self.completion = nil
        completion(controller, isSuccess)
    }

    func chain(replacingInitialStrategyWith strategy: NavigationStrategy?) -> [NavigationChainLink] {
        guard let strategy, let firstLink = chain.first else { return chain }

        return [
            NavigationChainLink(
                destination: firstLink.destination,
                strategy: strategy,
                animated: firstLink.animated,
                fallback: firstLink.fallback
            )
        ] + chain.dropFirst()
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
