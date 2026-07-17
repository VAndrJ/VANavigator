//
//  NavigationFailure.swift
//  VANavigator
//

import Foundation

/// Describes why a navigation attempt was rejected.
///
/// `Navigator.navigationFailureHandler` receives one value for every rejected strategy attempt. A failure is also
/// reported when the navigator subsequently continues with a configured fallback strategy.
public struct NavigationFailure: Error {
    /// The category of the rejected navigation attempt.
    nonisolated public enum Reason: String, Error, Sendable, Equatable, Hashable {
        /// The navigator no longer has a window.
        case windowUnavailable
        /// The navigator's window has no root view controller.
        case rootViewControllerUnavailable
        /// No suitable source view controller is available for the requested operation.
        case sourceViewControllerUnavailable
        /// No suitable navigation controller is available for the requested operation.
        case navigationControllerUnavailable
        /// No split view controller is available for the requested operation.
        case splitViewControllerUnavailable
        /// The requested split-view column has no navigation controller.
        case splitColumnNavigationControllerUnavailable
        /// The requested destination does not exist in the searched hierarchy.
        case destinationNotFound
        /// The destination already belongs to an incompatible hierarchy or cannot safely join the target hierarchy.
        case invalidDestinationHierarchy
        /// UIKit is already performing a transition that prevents the requested mutation.
        case transitionInProgress
        /// A popover strategy did not configure a source item, source view, or bar button item.
        case popoverAnchorMissing
        /// UIKit rejected or did not apply a requested stack or root-controller mutation.
        case mutationRejected
        /// UIKit rejected or did not complete a requested dismissal.
        case dismissalRejected
        /// A pending intercepted navigation was cancelled before it resumed.
        case interceptionCancelled
        /// The supplied `NavigationStrategy` is not supported by this version of the navigator.
        case unsupportedStrategy
    }

    public let reason: Reason
    /// The destination whose strategy was rejected, when the failure belongs to a destination-based request.
    public let destination: NavigationDestination?
    /// The strategy that was rejected, when the failure belongs to a strategy-based request.
    public let strategy: NavigationStrategy?

    public init(
        reason: Reason,
        destination: NavigationDestination? = nil,
        strategy: NavigationStrategy? = nil
    ) {
        self.reason = reason
        self.destination = destination
        self.strategy = strategy
    }
}
