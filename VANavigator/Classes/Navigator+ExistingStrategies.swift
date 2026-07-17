//
//  Navigator+ExistingStrategies.swift
//  VANavigator
//

import UIKit

extension Navigator {
    func executeCloseToExisting(_ execution: NavigationExecution) {
        guard let controller = window?.findController(destination: execution.destination) else {
            completeNavigationFailure(.destinationNotFound, execution: execution)

            return
        }

        dismissVisiblePresentationsOutsideHierarchy(
            of: controller,
            animated: execution.animated,
            completion: { [self] dismissalResult in
                guard case .success = dismissalResult else {
                    completeNavigationFailure(
                        dismissalResult.failureReason ?? .dismissalRejected,
                        execution: execution
                    )

                    return
                }

                selectTabIfNeededNow(
                    controller: controller,
                    completion: { [self] in
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

                                performNavigationEvents(
                                    event: execution.event,
                                    navigatorEvent: ResponderClosedToExistingEvent(),
                                    on: controller as? any UIViewController & Responder,
                                    completion: {
                                        execution.completion?(controller, true)
                                    }
                                )
                            }
                        )
                    }
                )
            }
        )
    }

    func executePopToExisting(
        _ strategy: PopToExistingNavigationStrategy,
        execution: NavigationExecution
    ) {
        guard let controller = findControllerForPop(
            destination: execution.destination,
            includingTabs: strategy.includingTabs
        ) else {
            completeNavigationFailure(.destinationNotFound, execution: execution)

            return
        }

        dismissVisiblePresentationsOutsideHierarchy(
            of: controller,
            animated: execution.animated,
            completion: { [self] dismissalResult in
                guard case .success = dismissalResult else {
                    completeNavigationFailure(
                        dismissalResult.failureReason ?? .dismissalRejected,
                        execution: execution
                    )

                    return
                }

                selectTabIfNeededNow(
                    controller: controller,
                    completion: { [self] in
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
                )
            }
        )
    }

    private func findControllerForPop(
        destination: NavigationDestination,
        includingTabs: Bool
    ) -> UIViewController? {
        var sourceController = window?.topController
        var searchedContainers = Set<ObjectIdentifier>()
        while let source = sourceController {
            let container = includingTabs
                ? source.orTabBarController ?? source.orNavigationController
                : source.orNavigationController
            if let container,
                searchedContainers.insert(ObjectIdentifier(container)).inserted,
                let controller = container.findController(destination: destination)
            {
                return controller
            }
            sourceController = presentingController(above: source)
        }

        return nil
    }

    private func presentingController(above controller: UIViewController) -> UIViewController? {
        var current: UIViewController? = controller
        var searchedControllers = Set<ObjectIdentifier>()
        while let candidate = current,
            searchedControllers.insert(ObjectIdentifier(candidate)).inserted
        {
            if let presentingViewController = candidate.presentingViewController {
                return presentingViewController
            }
            current = candidate.parent
        }

        return nil
    }
}
