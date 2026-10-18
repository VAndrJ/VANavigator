import Testing
import UIKit
import VANavigator

@Suite(.serialized)
final class CollapsedSplitControllerTests {
    @Test
    func `Reveals supplementary column in another tab after repeated size changes`() async throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true; window.rootViewController = nil }
        let primary = UIViewController()
        let supplementary = UIViewController()
        let split = UISplitViewController(style: .tripleColumn)
        split.setViewController(primary, for: .primary)
        split.setViewController(supplementary, for: .supplementary)
        split.setViewController(UIViewController(), for: .secondary)
        let tabs = UITabBarController()
        tabs.viewControllers = [split, UIViewController()]
        window.rootViewController = tabs
        window.makeKeyAndVisible()
        for size in [UIUserInterfaceSizeClass.regular, .compact, .regular, .compact] {
            split.traitOverrides.horizontalSizeClass = size
            split.view.layoutIfNeeded()
            await waitUntil("split size transition", timeout: 3) {
                split.transitionCoordinator == nil && split.isCollapsed == (size == .compact)
            }
            #expect(window.findController(destination: .controller(supplementary)) === supplementary)
        }
        split.show(.primary)
        await waitUntil("hidden supplementary", timeout: 3) {
            split.transitionCoordinator == nil && split.topController === primary
        }
        tabs.selectedIndex = 1
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let done = expectation(description: "revealed tab and supplementary")
        navigator.navigate(destination: .controller(supplementary), strategy: .closeToExisting, animated: false) { controller, success in
            #expect(success)
            #expect(controller === supplementary)
            #expect(tabs.selectedIndex == 0)
            #expect(window.topController === supplementary)
            done.fulfill()
        }
        await fulfillment(of: [done], timeout: 5)
    }

    @Test(arguments: [false, true], [false, true])
    func `Finds and reveals hidden secondary then continues queued navigation`(explicitNavigation: Bool, useIdentity: Bool) async throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true; window.rootViewController = nil }
        let primary = UIViewController()
        let secondary = MockRootViewController()
        let identity = MockRootControllerNavigationIdentity()
        secondary.navigationIdentity = identity
        let split = UISplitViewController(style: .doubleColumn)
        split.traitOverrides.horizontalSizeClass = .compact
        split.setViewController(UINavigationController(rootViewController: primary), for: .primary)
        split.setViewController(explicitNavigation ? UINavigationController(rootViewController: secondary) : secondary, for: .secondary)
        window.rootViewController = split
        window.makeKeyAndVisible()
        split.view.layoutIfNeeded()
        await waitUntil("split installation", timeout: 3) { split.transitionCoordinator == nil }
        split.show(.primary)
        await waitUntil("primary becomes visible", timeout: 3) {
            split.transitionCoordinator == nil && window.topController === primary
        }
        try #require(split.isCollapsed)
        try #require(window.topController === primary)
        #expect(window.findController(destination: .controller(secondary)) === secondary)
        #expect(window.findController(destination: .identity(identity)) === secondary)

        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        var failures: [NavigationFailure.Reason] = []
        navigator.navigationFailureHandler = { failures.append($0.reason) }
        let revealed = expectation(description: "hidden secondary revealed")
        let pushed = expectation(description: "queued push after reveal")
        let next = UIViewController()
        navigator.navigate(
            destination: useIdentity ? .identity(identity) : .controller(secondary),
            strategy: .closeToExisting,
            animated: false,
            event: ResponderMockEvent()
        ) { controller, success in
            #expect(success)
            #expect(controller === secondary)
            #expect(window.topController === secondary)
            #expect(secondary.isClosedEventHandled)
            #expect(secondary.isMockEventHandled)
            revealed.fulfill()
        }
        navigator.navigate(destination: .controller(next), strategy: .push(), animated: false) { controller, success in
            #expect(success)
            #expect(controller === next)
            pushed.fulfill()
        }
        await fulfillment(of: [revealed, pushed], timeout: 5)
        #expect(failures.isEmpty)
        #expect(window.topController === next)
        #expect(split.columnNavigationController(for: .secondary)?.viewControllers.contains(where: { $0 === secondary }) == true)
    }
}
