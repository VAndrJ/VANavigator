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

        navigateToExistingController(
            controller,
            navigatorEvent: ResponderClosedToExistingEvent(),
            execution: execution
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

        navigateToExistingController(
            controller,
            navigatorEvent: ResponderPoppedToExistingEvent(),
            execution: execution
        )
    }

    private func navigateToExistingController(
        _ controller: UIViewController,
        navigatorEvent: any ResponderEvent,
        execution: NavigationExecution
    ) {
        dismissVisiblePresentationsOutsideHierarchy(
            of: controller,
            animated: execution.animated,
            completion: { [self] dismissalResult in
                if case let .failure(reason) = dismissalResult {
                    completeNavigationFailure(reason, execution: execution)

                    return
                }

                selectTabIfNeededNow(controller: controller)
                closeNavigationPresentedResult(
                    controller: controller,
                    animated: execution.animated,
                    completion: { [self] result in
                        if case let .failure(reason) = result {
                            completeNavigationFailure(reason, execution: execution)

                            return
                        }

                        completeNavigationSuccess(
                            controller: controller,
                            navigatorEvent: navigatorEvent,
                            execution: execution
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
            sourceController = presentedAncestor(startingAt: source)?.presentingViewController
        }

        return nil
    }
}
