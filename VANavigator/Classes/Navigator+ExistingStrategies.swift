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

                revealExistingController(controller) { [self] result in
                    if case let .failure(reason) = result {
                        completeNavigationFailure(reason, execution: execution)

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

                            completeNavigationSuccess(
                                controller: controller,
                                navigatorEvent: navigatorEvent,
                                execution: execution
                            )
                        }
                    )
                }
            }
        )
    }

    private func revealExistingController(
        _ controller: UIViewController,
        completion: @escaping (Result<Void, NavigationFailure.Reason>) -> Void
    ) {
        guard let path = window?.rootViewController?.navigatorHierarchyPath(to: controller) else {
            completion(.failure(.destinationNotFound))

            return
        }

        func reveal(at index: Int) {
            guard index < path.count else {
                completion(.success(()))

                return
            }
            let container = path[index]
            if let tabs = container as? UITabBarController,
                let selected = tabs.viewControllers?.first(where: {
                    $0.findController(controller: controller, withPresented: true) != nil
                })
            {
                tabs.selectedViewController = selected
            }
            guard let split = container as? UISplitViewController,
                let column = split.navigatorColumn(containing: controller)
            else {
                reveal(at: index + 1)

                return
            }
            guard !split.containsActiveNavigatorTransition else {
                completion(.failure(.transitionInProgress))

                return
            }
            // UIKit cannot explicitly show the custom compact column.
            if column == .compact {
                guard split.isCollapsed else {
                    completion(.failure(.mutationRejected))

                    return
                }
                reveal(at: index + 1)

                return
            }
            guard window?.hasAdvancingNavigatorLayerClock == true else {
                completion(.failure(.invalidTransitionConfiguration))

                return
            }
            split.showNavigatorColumn(column) { [self] in
                guard window?.rootViewController?.navigatorHierarchyPath(to: controller) != nil,
                    split.navigatorColumn(containing: controller) == column
                else {
                    completion(.failure(.mutationRejected))

                    return
                }
                reveal(at: index + 1)
            }
        }

        reveal(at: 0)
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
