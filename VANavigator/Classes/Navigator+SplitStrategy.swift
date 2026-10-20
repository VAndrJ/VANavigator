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
        guard let window else {
            completeNavigationFailure(.windowUnavailable, execution: execution)

            return
        }
        guard window.hasAdvancingNavigatorLayerClock else {
            completeNavigationFailure(.invalidTransitionConfiguration, execution: execution)

            return
        }

        let splitController =
            window.topController?.orSplitViewController
            ?? window.rootViewController?.orSplitViewController
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

                    completeNavigationSuccess(
                        controller: controller,
                        execution: execution
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
                    if case let .failure(reason) = result {
                        completeNavigationFailure(reason, execution: execution)

                        return
                    }
                    guard splitController.columnNavigationController(for: column) === navigationController else {
                        completeNavigationFailure(.mutationRejected, execution: execution)

                        return
                    }

                    completeExistingControllerNavigation(
                        controller: controller,
                        navigatorEvent: ResponderPoppedToExistingEvent(),
                        execution: execution
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
                    if case let .failure(reason) = result {
                        completeNavigationFailure(reason, execution: execution)

                        return
                    }

                    let isCurrentColumnTop = splitController.columnNavigationController(for: column)
                        .map { $0 === navigationController && $0.topViewController === controller }
                        ?? false
                    guard isCurrentColumnTop else {
                        completeNavigationFailure(.mutationRejected, execution: execution)

                        return
                    }

                    completeNavigationSuccess(
                        controller: controller,
                        execution: execution
                    )
                }
            )
        }
    }
}
