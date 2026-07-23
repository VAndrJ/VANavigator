//
//  Navigator+PresentationStrategies.swift
//  VANavigator
//

import UIKit

extension Navigator {
    func executeReplaceWindowRoot(
        _ strategy: ReplaceWindowRootNavigationStrategy,
        execution: NavigationExecution
    ) {
        guard let window else {
            completeNavigationFailure(.windowUnavailable, execution: execution)

            return
        }

        let transition = execution.animated ? strategy.transition : nil
        guard transition?.isSupportedNavigatorRootTransition ?? true else {
            completeNavigationFailure(.invalidTransitionConfiguration, execution: execution)

            return
        }

        let controller = getController(destination: execution.destination)
        let currentRootController = window.rootViewController
        guard window.canSetNavigatorRootViewController(controller) else {
            let hasActiveTransition = controller.isBeingPresented
                || controller.isBeingDismissed
                || controller.transitionCoordinator != nil
                || currentRootController.map { window.containsActiveNavigatorTransition(in: $0) } == true
            completeNavigationFailure(
                hasActiveTransition ? .transitionInProgress : .invalidDestinationHierarchy,
                execution: execution
            )

            return
        }

        let navigatorEvent: (any ResponderEvent)? =
            currentRootController != nil && currentRootController !== controller
            ? ResponderReplacedWindowRootControllerEvent()
            : nil
        replaceWindowRoot(
            controller: controller,
            transition: transition,
            completion: { [self] in
                guard window.rootViewController === controller else {
                    completeNavigationFailure(.mutationRejected, execution: execution)

                    return
                }

                performNavigationEvents(
                    event: execution.event,
                    navigatorEvent: navigatorEvent,
                    on: controller as? any UIViewController & Responder,
                    completion: {
                        execution.completion?(controller, true)
                    }
                )
            }
        )
    }

    func executePresent(
        _ strategy: PresentNavigationStrategy,
        execution: NavigationExecution
    ) {
        guard window?.rootViewController != nil else {
            completeNavigationFailure(.rootViewControllerUnavailable, execution: execution)

            return
        }

        let requestedSourceController: UIViewController?
        switch strategy.source {
        case .topController:
            requestedSourceController = window?.topController
        case .navigationController:
            requestedSourceController = window?.topController?.orNavigationController
        case .tabBarController:
            requestedSourceController = window?.topController?.orTabBarController
        }
        guard let sourceController = presentableSource(from: requestedSourceController) else {
            completeNavigationFailure(.sourceViewControllerUnavailable, execution: execution)

            return
        }

        let controller = getController(destination: execution.destination)
        if let failureReason = presentationFailureReason(for: controller, from: sourceController) {
            completeNavigationFailure(failureReason, execution: execution)

            return
        }

        sourceController.present(
            controller,
            animated: execution.animated,
            completion: { [self] in
                DispatchQueue.main.async {
                    let isPresented = controller.presentingViewController != nil
                        || sourceController.presentedViewController === controller
                    guard isPresented else {
                        self.completeNavigationFailure(.mutationRejected, execution: execution)

                        return
                    }

                    self.performNavigationEvents(
                        event: execution.event,
                        navigatorEvent: nil,
                        on: controller as? any UIViewController & Responder,
                        completion: {
                            execution.completion?(controller, true)
                        }
                    )
                }
            }
        )
    }

    func executePopover(
        _ strategy: PopoverNavigationStrategy,
        execution: NavigationExecution
    ) {
        guard let sourceController = window?.topController,
            sourceController.viewIfLoaded?.window != nil || sourceController === window?.rootViewController
        else {
            completeNavigationFailure(.sourceViewControllerUnavailable, execution: execution)

            return
        }

        let controller = getController(destination: execution.destination)
        if let failureReason = presentationFailureReason(for: controller, from: sourceController) {
            completeNavigationFailure(failureReason, execution: execution)

            return
        }

        controller.modalPresentationStyle = .popover
        guard let popover = controller.popoverPresentationController else {
            completeNavigationFailure(.mutationRejected, execution: execution)

            return
        }

        strategy.configure(popover, controller)
        let hasPopoverAnchor: Bool
        if #available(iOS 16.0, *) {
            hasPopoverAnchor = popover.sourceItem != nil
                || popover.sourceView != nil
                || popover.barButtonItem != nil
        } else {
            hasPopoverAnchor = popover.sourceView != nil || popover.barButtonItem != nil
        }
        guard hasPopoverAnchor else {
            completeNavigationFailure(.popoverAnchorMissing, execution: execution)

            return
        }
        if let failureReason = presentationFailureReason(for: controller, from: sourceController) {
            completeNavigationFailure(failureReason, execution: execution)

            return
        }
        if popover.delegate == nil {
            popover.delegate = PopoverDelegate.shared
        }

        sourceController.present(
            controller,
            animated: execution.animated,
            completion: { [self] in
                DispatchQueue.main.async {
                    let isPresented = controller.presentingViewController != nil
                        || sourceController.presentedViewController === controller
                    guard isPresented else {
                        self.completeNavigationFailure(.mutationRejected, execution: execution)

                        return
                    }

                    self.performNavigationEvents(
                        event: execution.event,
                        navigatorEvent: nil,
                        on: controller as? any UIViewController & Responder,
                        completion: {
                            execution.completion?(controller, true)
                        }
                    )
                }
            }
        )
    }

    private func presentableSource(from controller: UIViewController?) -> UIViewController? {
        guard let controller else { return nil }
        if controller.viewIfLoaded?.window != nil || controller === window?.rootViewController {
            return controller
        } else if let navigationController = controller.orNavigationController,
            navigationController.viewIfLoaded?.window != nil
        {
            return navigationController
        } else if let tabBarController = controller.orTabBarController,
            tabBarController.viewIfLoaded?.window != nil
        {
            return tabBarController
        }

        var visibleController = window?.rootViewController
        while let presentedController = visibleController?.presentedViewController,
            !presentedController.isBeingDismissed
        {
            visibleController = presentedController
        }

        return visibleController
    }

    private func presentationFailureReason(
        for controller: UIViewController,
        from sourceController: UIViewController
    ) -> NavigationFailure.Reason? {
        guard !canPresent(controller, from: sourceController) else { return nil }

        let hasActiveTransition = controller.isBeingPresented
            || controller.isBeingDismissed
            || controller.transitionCoordinator != nil
            || sourceController.isBeingDismissed
            || sourceController.isBeingPresented
            || sourceController.transitionCoordinator != nil

        return hasActiveTransition ? .transitionInProgress : .invalidDestinationHierarchy
    }

    private func canPresent(
        _ controller: UIViewController,
        from sourceController: UIViewController
    ) -> Bool {
        return controller !== sourceController
            && controller.parent == nil
            && controller.presentingViewController == nil
            && controller.presentedViewController == nil
            && controller.transitionCoordinator == nil
            && controller.viewIfLoaded?.window == nil
            && controller.findController(controller: sourceController, withPresented: true) == nil
            && sourceController.presentedViewController == nil
            && !sourceController.isBeingDismissed
            && !sourceController.isBeingPresented
            && sourceController.transitionCoordinator == nil
    }
}
