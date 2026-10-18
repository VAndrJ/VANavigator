//
//  Navigator+NavigationExecution.swift
//  VANavigator
//

import UIKit

extension Navigator {
    func executeNavigation(_ execution: NavigationExecution) {
        guard window != nil else {
            completeNavigationFailure(.windowUnavailable, execution: execution)

            return
        }

        switch execution.strategy {
        case _ as RemoveFromStackNavigationStrategy:
            executeRemoveFromStack(execution)
        case let strategy as CloseIfTopNavigationStrategy:
            executeCloseIfTop(strategy, execution: execution)
        case let strategy as ReplaceWindowRootNavigationStrategy:
            executeReplaceWindowRoot(strategy, execution: execution)
        case let strategy as PresentNavigationStrategy:
            executePresent(strategy, execution: execution)
        case _ as CloseToExistingNavigationStrategy:
            executeCloseToExisting(execution)
        case let strategy as PushNavigationStrategy:
            executePush(strategy, execution: execution)
        case let strategy as PopToExistingNavigationStrategy:
            executePopToExisting(strategy, execution: execution)
        case _ as ReplaceNavigationRootNavigationStrategy:
            executeReplaceNavigationRoot(execution)
        case let strategy as PopoverNavigationStrategy:
            executePopover(strategy, execution: execution)
        case let strategy as SplitNavigationStrategy:
            executeSplit(strategy, execution: execution)
        default:
            if execution.shouldReportFailure {
                reportNavigationFailure(
                    reason: .unsupportedStrategy,
                    destination: execution.destination,
                    strategy: execution.strategy
                )
            }
            execution.completion?(nil, false)
        }
    }

    func completeNavigationFailure(
        _ reason: NavigationFailure.Reason,
        execution: NavigationExecution
    ) {
        if execution.shouldReportFailure {
            reportNavigationFailure(
                reason: reason,
                destination: execution.destination,
                strategy: execution.strategy
            )
        }
        guard let fallback = execution.fallback else {
            execution.completion?(nil, false)

            return
        }

        navigate(
            to: fallback.destination,
            strategy: fallback.strategy,
            animated: fallback.animated,
            fallback: fallback.fallback,
            event: execution.event,
            chainContext: execution.chainContext,
            completion: execution.completion
        )
    }

    /// Delivers responder events before completing the navigation and releasing queued work.
    func completeNavigationSuccess(
        controller: UIViewController,
        navigatorEvent: (any ResponderEvent)? = nil,
        execution: NavigationExecution
    ) {
        guard let responder = controller as? any Responder,
            navigatorEvent != nil || execution.event != nil
        else {
            execution.completion?(controller, true)

            return
        }

        Task { [self] in
            if let navigatorEvent {
                _ = await responder.handle(event: navigatorEvent)
            }
            if let event = execution.event {
                _ = await responder.handle(event: event)
            }
            withExtendedLifetime(self) {
                execution.completion?(controller, true)
            }
        }
    }
}

struct NavigationExecution {
    let destination: NavigationDestination
    let strategy: NavigationStrategy
    let animated: Bool
    let fallback: NavigationChainLink?
    let event: (any ResponderEvent)?
    let chainContext: NavigationChainContext?
    let shouldReportFailure: Bool
    let completion: ((UIViewController?, Bool) -> Void)?
}
