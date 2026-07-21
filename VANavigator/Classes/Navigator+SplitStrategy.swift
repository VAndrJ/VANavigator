//
//  Navigator+SplitStrategy.swift
//  VANavigator
//

import UIKit

extension Navigator {
    func executeSplit(
        _ strategy: SplitNavigationStrategy,
        execution: NavigationExecution
    ) {
        let splitController = window?.topController?.orSplitViewController
            ?? window?.rootViewController?.orSplitViewController
        let column: UISplitViewController.Column
        let action: SplitStrategy.SplitAction
        switch strategy.strategy {
        case let .primary(splitAction):
            column = .primary
            action = splitAction
        case let .secondary(splitAction):
            column = .secondary
            action = splitAction
        }

        guard let splitController else {
            completeNavigationFailure(.splitViewControllerUnavailable, execution: execution)

            return
        }
        guard let initialNavigationController = splitController.columnNavigationController(for: column) else {
            completeNavigationFailure(.splitColumnNavigationControllerUnavailable, execution: execution)

            return
        }

        switch action {
        case .replace:
            executeSplitReplace(
                execution,
                splitController: splitController,
                column: column,
                initialNavigationController: initialNavigationController
            )
        case .pop:
            executeSplitPop(
                execution,
                splitController: splitController,
                column: column,
                initialNavigationController: initialNavigationController
            )
        case .push:
            executeSplitPush(
                execution,
                splitController: splitController,
                column: column,
                initialNavigationController: initialNavigationController
            )
        }
    }

    private func executeSplitReplace(
        _ execution: NavigationExecution,
        splitController: UISplitViewController,
        column: UISplitViewController.Column,
        initialNavigationController: UINavigationController
    ) {
        let controller = getController(destination: execution.destination)
        guard initialNavigationController.canSetNavigationRoot(controller) else {
            completeNavigationFailure(
                initialNavigationController.canMutateNavigationStack
                    ? .invalidDestinationHierarchy
                    : .transitionInProgress,
                execution: execution
            )

            return
        }

        splitController.showNavigatorColumn(column) { [self] in
            guard let navigationController = splitController.columnNavigationController(for: column) else {
                completeNavigationFailure(.splitColumnNavigationControllerUnavailable, execution: execution)

                return
            }
            guard navigationController.canSetNavigationRoot(controller) else {
                completeNavigationFailure(
                    navigationController.canMutateNavigationStack
                        ? .invalidDestinationHierarchy
                        : .transitionInProgress,
                    execution: execution
                )

                return
            }

            navigationController.setViewControllers(
                [controller],
                animated: execution.animated,
                completion: { [self] in
                    guard splitController.columnNavigationController(for: column) === navigationController,
                        navigationController.viewControllers.count == 1,
                        navigationController.topViewController === controller
                    else {
                        completeNavigationFailure(.mutationRejected, execution: execution)

                        return
                    }

                    performNavigationEvents(
                        event: execution.event,
                        navigatorEvent: nil,
                        on: controller as? any UIViewController & Responder,
                        completion: {
                            execution.completion?(controller, true)
                        }
                    )
                }
            )
        }
    }

    private func executeSplitPop(
        _ execution: NavigationExecution,
        splitController: UISplitViewController,
        column: UISplitViewController.Column,
        initialNavigationController: UINavigationController
    ) {
        guard initialNavigationController.findController(destination: execution.destination) != nil else {
            completeNavigationFailure(.destinationNotFound, execution: execution)

            return
        }

        splitController.showNavigatorColumn(column) { [self] in
            guard let navigationController = splitController.columnNavigationController(for: column) else {
                completeNavigationFailure(.splitColumnNavigationControllerUnavailable, execution: execution)

                return
            }
            guard let controller = navigationController.findController(destination: execution.destination) else {
                completeNavigationFailure(.destinationNotFound, execution: execution)

                return
            }

            closeNavigationPresentedResult(
                controller: controller,
                animated: execution.animated,
                completion: { [self] result in
                    guard case .success = result else {
                        completeNavigationFailure(
                            result.failureReason ?? .mutationRejected,
                            execution: execution
                        )

                        return
                    }
                    guard splitController.columnNavigationController(for: column) === navigationController else {
                        completeNavigationFailure(.mutationRejected, execution: execution)

                        return
                    }

                    performNavigationEvents(
                        event: execution.event,
                        navigatorEvent: ResponderPoppedToExistingEvent(),
                        on: controller as? any UIViewController & Responder,
                        completion: {
                            execution.completion?(controller, true)
                        }
                    )
                }
            )
        }
    }

    private func executeSplitPush(
        _ execution: NavigationExecution,
        splitController: UISplitViewController,
        column: UISplitViewController.Column,
        initialNavigationController: UINavigationController
    ) {
        let controller = getController(destination: execution.destination)
        guard initialNavigationController.canPushViewController(controller) else {
            completeNavigationFailure(
                initialNavigationController.canMutateNavigationStack
                    ? .invalidDestinationHierarchy
                    : .transitionInProgress,
                execution: execution
            )

            return
        }

        splitController.showNavigatorColumn(column) { [self] in
            guard let navigationController = splitController.columnNavigationController(for: column) else {
                completeNavigationFailure(.splitColumnNavigationControllerUnavailable, execution: execution)

                return
            }

            push(
                controller: controller,
                to: navigationController,
                animated: execution.animated,
                navigation: nil,
                completion: { [self] result in
                    let isCurrentColumnTop = splitController.columnNavigationController(for: column)
                        .map { $0 === navigationController && $0.topViewController === controller }
                        ?? false
                    guard isCurrentColumnTop else {
                        completeNavigationFailure(
                            result.failureReason ?? .mutationRejected,
                            execution: execution
                        )

                        return
                    }

                    performNavigationEvents(
                        event: execution.event,
                        navigatorEvent: nil,
                        on: controller as? any UIViewController & Responder,
                        completion: {
                            execution.completion?(controller, true)
                        }
                    )
                }
            )
        }
    }
}
