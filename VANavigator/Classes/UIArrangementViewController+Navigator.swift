import UIKit

extension UIViewController {
    /// `nil` means this is not an arrangement container. An empty visible list is meaningful.
    var navigatorArrangementChildren: (visible: [UIViewController], all: [UIViewController])? {
        // The submodule check preserves support for SDKs predating iOS 27.1. Exclude
        // Mac Catalyst for the iOS 27.1 API compilation issue in Xcode 27.1 (185924957).
        #if canImport(UIKit.UIArrangementViewController) && !targetEnvironment(macCatalyst)
        if #available(iOS 27.1, *), let arrangement = self as? UIArrangementViewController {
            let placements: [UIArrangementViewController.ViewPlacement] = [.primary, .secondary]
            let entries = placements.enumerated().compactMap { index, placement -> (controller: UIViewController, hidden: Bool, zIndex: Int, order: Int)? in
                guard let controller = arrangement.viewController(for: placement) else { return nil }
                let state = arrangement.state(for: placement)
                // During adaptation UIKit can detach a placement before updating its reported
                // state. An offscreen navigation ancestor is fine; a detached placement is not.
                let detached = if let containerView = arrangement.viewIfLoaded, let view = controller.viewIfLoaded {
                    !view.isDescendant(of: containerView)
                } else {
                    false
                }

                return (controller, state?.isHidden == true || detached, state?.zIndex ?? 0, index)
            }.sorted {
                // Prefer primary for equal stacking levels, including before the first layout.
                $0.zIndex == $1.zIndex ? $0.order < $1.order : $0.zIndex > $1.zIndex
            }
            let visible = entries.filter { !$0.hidden && !$0.controller.isBeingDismissed }.map(\.controller)
            var all = visible
            for controller in entries.map(\.controller) + children.reversed()
            where !all.contains(where: { $0 === controller }) {
                all.append(controller)
            }

            return (visible, all)
        }
        #endif

        return nil
    }

    func navigatorArrangementAllowsNavigation(to controller: UIViewController) -> Bool {
        guard self !== controller, navigatorArrangementChildren != nil else { return true }
        // UIKit may defer reinstalling placements until layout after a navigation pop.
        // Resolve that pending layout inside the navigation operation, never during lookup.
        viewIfLoaded?.layoutIfNeeded()
        guard let arrangement = navigatorArrangementChildren else { return true }

        return arrangement.visible.contains {
            $0.findController(controller: controller, withPresented: true) != nil
        }
    }
}
