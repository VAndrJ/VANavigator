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

                revealExistingController(controller, animated: execution.animated) { [self] result in
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
                            completeExistingControllerNavigation(
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

    func completeExistingControllerNavigation(
        controller: UIViewController,
        navigatorEvent: any ResponderEvent,
        execution: NavigationExecution
    ) {
        completeNavigationSuccess(
            controller: controller,
            navigatorEvent: navigatorEvent,
            validate: { [self] in existingControllerNavigationFailure(to: controller) },
            execution: execution
        )
    }

    private func existingControllerNavigationFailure(to controller: UIViewController) -> NavigationFailure.Reason? {
        // A navigation pop can bring an offscreen arrangement back into the window.
        // All existing-controller strategies must validate its layout after that transition.
        guard let path = window?.rootViewController?.navigatorHierarchyPath(to: controller) else {
            return .destinationNotFound
        }
        if path.contains(where: { $0.navigatorArrangementChildren != nil }) {
            window?.layoutIfNeeded()
        }
        guard path.allSatisfy({ $0.navigatorArrangementAllowsNavigation(to: controller) }) else {
            return .mutationRejected
        }
        guard let currentPath = window?.rootViewController?.navigatorHierarchyPath(to: controller) else {
            return .destinationNotFound
        }
        let navigationStacksAreRevealed = zip(currentPath, currentPath.dropFirst()).allSatisfy { container, child in
            guard let navigation = container as? UINavigationController,
                navigation.viewControllers.contains(where: { $0 === child })
            else {
                return true
            }

            return navigation.topViewController === child
        }

        return navigationStacksAreRevealed ? nil : .mutationRejected
    }

    private func revealExistingController(
        _ controller: UIViewController,
        animated: Bool,
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
            // Reveal outer stacks before entering their custom containers and inner stacks.
            // A split-column reveal may have changed containment since the original path was captured.
            if let navigation = container as? UINavigationController,
                let currentPath = window?.rootViewController?.navigatorHierarchyPath(to: controller),
                let navigationIndex = currentPath.firstIndex(where: { $0 === navigation }),
                let child = currentPath.dropFirst(navigationIndex + 1).first,
                navigation.viewControllers.contains(where: { $0 === child })
            {
                guard navigation.canMutateNavigationStack else {
                    completion(.failure(.transitionInProgress))

                    return
                }
                navigation.popToViewController(child, animated: animated, resultCompletion: { [self] didPop in
                    guard didPop,
                        navigation.topViewController === child,
                        window?.rootViewController?.navigatorHierarchyPath(to: controller) != nil
                    else {
                        completion(.failure(.mutationRejected))

                        return
                    }
                    reveal(at: index + 1)
                })

                return
            }
            if let tabs = container as? UITabBarController,
                let selected = tabs.viewControllers?.first(where: {
                    $0.findController(controller: controller, withPresented: true) != nil
                })
            {
                tabs.selectNavigatorController(selected, animated: animated) {
                    reveal(at: index + 1)
                }

                return
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
