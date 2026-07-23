//
//  Navigator+StackStrategies.swift
//  VANavigator
//

import UIKit

extension Navigator {
    func executeRemoveFromStack(_ execution: NavigationExecution) {
        guard let navigationController = window?.topController?.orNavigationController else {
            completeNavigationFailure(.navigationControllerUnavailable, execution: execution)

            return
        }
        guard navigationController.canMutateNavigationStack else {
            completeNavigationFailure(.transitionInProgress, execution: execution)

            return
        }

        if navigationController.topViewController.map({
            execution.destination.isEqual(to: .controller($0))
        }) == true {
            navigate(
                to: execution.destination,
                strategy: .closeIfTop(tryToDismiss: false),
                animated: execution.animated,
                fallback: nil,
                event: execution.event,
                chainContext: execution.chainContext,
                shouldIntercept: false,
                shouldReportFailure: false,
                completion: { [self] controller, isSuccess in
                    if isSuccess {
                        execution.completion?(controller, true)
                    } else {
                        completeNavigationFailure(.mutationRejected, execution: execution)
                    }
                }
            )
        } else if let index = navigationController.viewControllers.firstIndex(
            where: { execution.destination.isEqual(to: .controller($0)) }
        ) {
            let removedController = navigationController.viewControllers[index]
            let previousCount = navigationController.viewControllers.count
            navigationController.viewControllers.remove(at: index)

            if navigationController.viewControllers.count == previousCount - 1,
                !navigationController.viewControllers.contains(where: { $0 === removedController })
            {
                execution.completion?(nil, true)
            } else {
                completeNavigationFailure(.mutationRejected, execution: execution)
            }
        } else {
            completeNavigationFailure(.destinationNotFound, execution: execution)
        }
    }

    func executeCloseIfTop(
        _ strategy: CloseIfTopNavigationStrategy,
        execution: NavigationExecution
    ) {
        func isMatchingDestination(_ controller: UIViewController?) -> Bool {
            controller.map { execution.destination.isEqual(to: .controller($0)) } ?? false
        }
        func presentedContainer(for controller: UIViewController) -> UIViewController? {
            presentedAncestor(startingAt: controller)
        }
        func completeSuccess() {
            withExtendedLifetime(self) {
                execution.completion?(nil, true)
            }
        }
        func dismiss(_ presentedController: UIViewController) {
            dismissPresentedController(
                presentedController,
                animated: execution.animated,
                completion: { [self] result in
                    switch result {
                    case .success:
                        completeSuccess()
                    case let .failure(reason):
                        completeNavigationFailure(reason, execution: execution)
                    }
                }
            )
        }

        guard let controller = window?.topController else {
            completeNavigationFailure(.sourceViewControllerUnavailable, execution: execution)

            return
        }

        if strategy.tryToPop,
            let navigationController = controller.orNavigationController,
            isMatchingDestination(navigationController.topViewController)
        {
            strategy.navigation?(navigationController)
            navigationController.popViewController(
                animated: execution.animated,
                completion: { [self] isSuccess in
                    if isSuccess {
                        completeSuccess()
                    } else if strategy.tryToDismiss,
                        let presentedController = presentedContainer(for: controller)
                    {
                        dismiss(presentedController)
                    } else {
                        completeNavigationFailure(.mutationRejected, execution: execution)
                    }
                }
            )
        } else if strategy.tryToDismiss,
            isMatchingDestination(controller),
            let presentedController = presentedContainer(for: controller)
        {
            dismiss(presentedController)
        } else {
            completeNavigationFailure(.destinationNotFound, execution: execution)
        }
    }

    func executePush(
        _ strategy: PushNavigationStrategy,
        execution: NavigationExecution
    ) {
        let controller = getController(destination: execution.destination)
        let sourceController = window?.topController?.orNavigationController ?? window?.rootViewController
        pushNow(
            sourceController: sourceController,
            controller: controller,
            animated: execution.animated,
            navigation: strategy.navigation,
            completion: { [self] result in
                switch result {
                case .success:
                    performNavigationEvents(
                        event: execution.event,
                        navigatorEvent: nil,
                        on: controller as? any UIViewController & Responder,
                        completion: {
                            execution.completion?(controller, true)
                        }
                    )
                case let .failure(reason):
                    completeNavigationFailure(reason, execution: execution)
                }
            }
        )
    }

    func executeReplaceNavigationRoot(_ execution: NavigationExecution) {
        guard let navigationController = window?.topController?.orNavigationController else {
            completeNavigationFailure(.navigationControllerUnavailable, execution: execution)

            return
        }

        let controller = getController(destination: execution.destination)
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
                guard navigationController.viewControllers.count == 1,
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
