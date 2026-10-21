import Testing
import UIKit
import VANavigator

#if canImport(UIKit.UIArrangementViewController) && !targetEnvironment(macCatalyst)
@Suite(.serialized)
final class ArrangementControllerTests {
    @available(iOS 27.1, *)
    @Test(arguments: [false, true])
    func `Overlay lookup follows stacking order rather than insertion order`(secondaryFirst: Bool) async throws {
        let arrangement = UIArrangementViewController()
        let primary = UIViewController()
        let secondary = UIViewController()
        let identity = MockControllerNavigationIdentity()
        primary.navigationIdentity = identity
        secondary.navigationIdentity = identity
        if secondaryFirst { arrangement.setViewController(secondary, for: .secondary) }
        arrangement.setViewController(primary, for: .primary)
        if !secondaryFirst { arrangement.setViewController(secondary, for: .secondary) }
        arrangement.updateArrangement(.overlay)
        let window = try makeWindow(root: arrangement)
        defer { window.isHidden = true; window.rootViewController = nil }
        arrangement.view.layoutIfNeeded()
        await waitUntil("overlay state", timeout: 3) { arrangement.state(for: .primary) != nil }
        #expect(arrangement.state(for: .primary)?.isHidden == false)
        #expect(arrangement.topController === primary)
        #expect(arrangement.findController(identity: identity, withPresented: false) === primary)
        #expect(arrangement.findController(controller: secondary, withPresented: false) === secondary)

        let presented = UIViewController()
        presented.navigationIdentity = identity
        arrangement.present(presented, animated: false)
        await waitUntil("presentation", timeout: 3) { !presented.isBeingPresented && presented.viewIfLoaded?.window != nil }
        #expect(arrangement.topController === presented)
        #expect(arrangement.findController(identity: identity, withPresented: true) === presented)
        #expect(arrangement.findController(identity: identity, withPresented: false) === primary)
    }

    @available(iOS 27.1, *)
    @Test
    func `Axis changes retain hidden content and reject navigation without changing layout`() async throws {
        let host = UIViewController()
        host.traitOverrides.horizontalSizeClass = .regular
        let arrangement = UIArrangementViewController()
        let primary = UIViewController()
        let secondary = MockRootViewController()
        let identity = MockRootControllerNavigationIdentity()
        secondary.navigationIdentity = identity
        arrangement.setViewController(primary, for: .primary)
        arrangement.setViewController(secondary, for: .secondary)
        arrangement.updateArrangement(.split.axes(.horizontal))
        host.addChild(arrangement)
        host.view.addSubview(arrangement.view)
        arrangement.didMove(toParent: host)
        let window = try makeWindow(root: host)
        defer { window.isHidden = true; window.rootViewController = nil }
        for wide in [false, true, false, true, false] {
            arrangement.view.frame = CGRect(x: 0, y: 0, width: wide ? 600 : 300, height: wide ? 300 : 600)
            arrangement.updateArrangement(.split.axes(.horizontal))
            arrangement.view.setNeedsLayout()
            arrangement.view.layoutIfNeeded()
            await waitUntil("arrangement axis change", timeout: 3) {
                secondary.view.isDescendant(of: arrangement.view) == wide
            }
            #expect(arrangement.topController === primary)
            #expect(window.findController(destination: .controller(secondary)) === secondary)
            #expect(window.findController(destination: .identity(identity)) === secondary)
        }

        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        var failures: [NavigationFailure.Reason] = []
        navigator.navigationFailureHandler = { failures.append($0.reason) }
        let finished = expectation(description: "hidden destination uses fallback")
        let continued = expectation(description: "queue continues after hidden destination")
        navigator.navigate(
            destination: .controller(secondary),
            strategy: .closeToExisting,
            animated: false,
            fallback: NavigationChainLink(destination: .controller(primary), strategy: .closeToExisting, animated: false)
        ) { controller, success in
            #expect(success)
            #expect(controller === primary)
            #expect(!secondary.isClosedEventHandled)
            #expect(!secondary.view.isDescendant(of: arrangement.view))
            finished.fulfill()
        }
        navigator.navigate(destination: .controller(primary), strategy: .closeToExisting, animated: false) { _, success in
            #expect(success)
            continued.fulfill()
        }
        await fulfillment(of: [finished, continued], timeout: 3)
        #expect(failures == [.mutationRejected])
    }

    @available(iOS 27.1, *)
    @Test(arguments: [false, true], [false, true])
    func `Navigation outside arrangement pushes and returns to retained content`(pop: Bool, presented: Bool) async throws {
        let arrangement = UIArrangementViewController()
        let primary = MockRootViewController()
        arrangement.setViewController(primary, for: .primary)
        arrangement.setViewController(UIViewController(), for: .secondary)
        arrangement.updateArrangement(.split)
        let navigation = UINavigationController(rootViewController: arrangement)
        let root = presented ? UIViewController() : navigation
        let window = try makeWindow(root: root)
        defer { window.isHidden = true; window.rootViewController = nil }
        if presented {
            root.present(navigation, animated: false)
            await waitUntil("presented arrangement", timeout: 3) {
                !navigation.isBeingPresented && navigation.viewIfLoaded?.window != nil
            }
        }
        navigation.view.layoutIfNeeded()
        await waitUntil("arrangement navigation installed", timeout: 3) {
            navigation.transitionCoordinator == nil && primary.viewIfLoaded?.window != nil
        }
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        var failures: [NavigationFailure.Reason] = []
        navigator.navigationFailureHandler = { failures.append($0.reason) }
        for _ in 0..<3 {
            let detail = UIViewController()
            let pushed = expectation(description: "push from arrangement")
            let returned = expectation(description: "return to arrangement child")
            navigator.navigate(destination: .controller(detail), strategy: .push(), animated: false) { controller, success in
                #expect(success)
                #expect(controller === detail)
                pushed.fulfill()
            }
            navigator.navigate(
                destination: .controller(primary),
                strategy: pop ? .popToExisting() : .closeToExisting,
                animated: false,
                event: ResponderMockEvent()
            ) { controller, success in
                #expect(success)
                #expect(controller === primary)
                #expect(window.topController === primary)
                #expect(navigation.topViewController === arrangement)
                #expect(primary.isMockEventHandled)
                if presented { #expect(root.presentedViewController === navigation) }
                returned.fulfill()
            }
            await fulfillment(of: [pushed, returned], timeout: 3)
        }
        #expect(failures.isEmpty)
    }

    @available(iOS 27.1, *)
    @Test(arguments: [false, true])
    func `Root replacement installs arrangement with navigation inside its panels`(overlay: Bool) async throws {
        let primary = MockRootViewController()
        let secondary = UIViewController()
        let primaryNavigation = UINavigationController(rootViewController: primary)
        let secondaryNavigation = UINavigationController(rootViewController: secondary)
        let arrangement = UIArrangementViewController()
        arrangement.setViewController(primaryNavigation, for: .primary)
        arrangement.setViewController(secondaryNavigation, for: .secondary)
        if overlay {
            arrangement.updateArrangement(.overlay)
        } else {
            arrangement.updateArrangement(.split)
        }
        let window = try makeWindow(root: UIViewController())
        defer { window.isHidden = true; window.rootViewController = nil }
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        var failures: [NavigationFailure.Reason] = []
        navigator.navigationFailureHandler = { failures.append($0.reason) }
        let installed = expectation(description: "arrangement replaces window root")
        let pushed = expectation(description: "detail stays inside primary panel")
        let returned = expectation(description: "return to primary panel")
        let exited = expectation(description: "replace arrangement root again")
        let detail = UIViewController()
        let main = UIViewController()
        var completionOrder: [String] = []

        navigator.navigate(destination: .controller(arrangement), strategy: .replaceWindowRoot()) { controller, success in
            #expect(success)
            #expect(controller === arrangement)
            #expect(window.rootViewController === arrangement)
            completionOrder.append("root")
            installed.fulfill()
        }
        await fulfillment(of: [installed], timeout: 3)
        window.layoutIfNeeded()
        arrangement.view.layoutIfNeeded()
        await waitUntil("root arrangement panel installed", timeout: 3) {
            primary.viewIfLoaded?.window === window && primaryNavigation.transitionCoordinator == nil
        }
        try #require(window.topController === primary)

        navigator.navigate(destination: .controller(detail), strategy: .push(), animated: false) { controller, success in
            #expect(success)
            #expect(controller === detail)
            #expect(window.rootViewController === arrangement)
            #expect(primaryNavigation.topViewController === detail)
            #expect(secondaryNavigation.viewControllers.count == 1)
            completionOrder.append("push")
            pushed.fulfill()
        }
        navigator.navigate(
            destination: .controller(primary),
            strategy: .closeToExisting,
            animated: false,
            event: ResponderMockEvent()
        ) { controller, success in
            #expect(success)
            #expect(controller === primary)
            #expect(primaryNavigation.topViewController === primary)
            #expect(window.topController === primary)
            #expect(primary.isMockEventHandled)
            completionOrder.append("return")
            returned.fulfill()
        }
        navigator.navigate(destination: .controller(main), strategy: .replaceWindowRoot()) { controller, success in
            #expect(success)
            #expect(controller === main)
            #expect(window.rootViewController === main)
            completionOrder.append("exit")
            exited.fulfill()
        }
        await fulfillment(of: [installed, pushed, returned, exited], timeout: 5)
        #expect(completionOrder == ["root", "push", "return", "exit"])
        #expect(failures.isEmpty)
    }

    @available(iOS 27.1, *)
    @Test(arguments: [false, true], [false, true])
    func `Split pop validates arrangement visibility before events and continues queued work`(
        targetHidden: Bool,
        useFallback: Bool
    ) async throws {
        let primary = MockPopViewController()
        let target = MockPopViewController()
        let identity = MockPopControllerNavigationIdentity()
        target.navigationIdentity = identity
        let arrangement = UIArrangementViewController()
        arrangement.setViewController(primary, for: .primary)
        arrangement.setViewController(target, for: .secondary)
        arrangement.updateArrangement(.split.axes(.horizontal))
        let host = UIViewController()
        host.traitOverrides.horizontalSizeClass = .regular
        host.addChild(arrangement)
        host.view.addSubview(arrangement.view)
        arrangement.didMove(toParent: host)
        // Control the arrangement's aspect ratio independently of the split column's width.
        // UIKit gives container views a flexible autoresizing mask by default. Keep this
        // fixture's size fixed when the split column is installed or revealed after a pop.
        arrangement.view.autoresizingMask = []
        arrangement.view.frame = CGRect(
            x: 0, y: 0,
            width: targetHidden ? 300 : 600,
            height: targetHidden ? 600 : 300
        )
        let navigation = UINavigationController(rootViewController: host)
        let split = UISplitViewController(style: .doubleColumn)
        split.setViewController(UIViewController(), for: .primary)
        split.setViewController(navigation, for: .secondary)
        let window = try makeWindow(root: split)
        defer { window.isHidden = true; window.rootViewController = nil }
        split.show(.secondary)
        window.layoutIfNeeded()
        arrangement.view.layoutIfNeeded()
        await waitUntil("arrangement split column installed", timeout: 3) {
            split.transitionCoordinator == nil
                && primary.viewIfLoaded?.window === window
                && target.view.isDescendant(of: arrangement.view) == !targetHidden
        }
        try #require(primary.viewIfLoaded?.window === window)
        try #require(target.view.isDescendant(of: arrangement.view) == !targetHidden)

        let detail = UIViewController()
        navigation.pushViewController(detail, animated: false)
        await waitUntil("detail covers arrangement", timeout: 3) {
            navigation.transitionCoordinator == nil && host.viewIfLoaded?.window == nil
        }
        try #require(navigation.topViewController === detail)
        #expect(window.findController(destination: .identity(identity)) === target)

        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        var failures: [NavigationFailure.Reason] = []
        navigator.navigationFailureHandler = { failures.append($0.reason) }
        let completed = expectation(description: "split pop to arrangement child")
        let continued = expectation(description: "queued split pop after visibility check")
        var completionOrder: [String] = []
        navigator.navigate(
            destination: .identity(identity),
            strategy: .split(strategy: .secondary(action: .pop)),
            animated: false,
            fallback: useFallback
                ? NavigationChainLink(
                    destination: .controller(primary),
                    strategy: .split(strategy: .secondary(action: .pop)),
                    animated: false
                )
                : nil,
            event: ResponderMockEvent()
        ) { controller, success in
            #expect(success == (!targetHidden || useFallback))
            if targetHidden {
                #expect(controller === (useFallback ? primary : nil))
            } else {
                #expect(controller === target)
            }
            #expect(target.isPoppedEventHandled == !targetHidden)
            #expect(target.isMockEventHandled == !targetHidden)
            completionOrder.append("pop")
            completed.fulfill()
        }
        navigator.navigate(
            destination: .controller(primary),
            strategy: .split(strategy: .secondary(action: .pop)),
            animated: false
        ) { controller, success in
            #expect(success)
            #expect(controller === primary)
            completionOrder.append("queued")
            continued.fulfill()
        }
        await fulfillment(of: [completed, continued], timeout: 5)
        #expect(failures == (targetHidden ? [.mutationRejected] : []))
        #expect(completionOrder == ["pop", "queued"])
        #expect(navigation.topViewController === host)
        #expect(target.view.isDescendant(of: arrangement.view) == !targetHidden)
    }

    private func makeWindow(root: UIViewController) throws -> UIWindow {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = root
        window.makeKeyAndVisible()

        return window
    }
}
#endif
