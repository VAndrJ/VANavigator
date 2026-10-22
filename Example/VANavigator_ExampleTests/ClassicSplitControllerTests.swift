import Testing
import UIKit
import VANavigator

@Suite(.serialized)
final class ClassicSplitControllerTests {
    @Test
    func `Classic split lookup searches both navigation hierarchies`() {
        let primary = UIViewController()
        let secondary = UIViewController()
        secondary.navigationIdentity = MockPushControllerNavigationIdentity()
        let split = UISplitViewController()
        split.viewControllers = [
            UINavigationController(rootViewController: primary),
            UINavigationController(rootViewController: secondary),
        ]
        let window = UIWindow()
        window.rootViewController = split

        #expect(window.topController === secondary)
        #expect(window.findController(destination: .controller(primary)) === primary)
        #expect(window.findController(destination: .identity(MockPushControllerNavigationIdentity())) === secondary)
        #expect(split.columnNavigationController(for: .primary) == nil)
        #expect(split.columnNavigationController(for: .secondary) == nil)
    }

    @Test
    func `Classic split lookup handles empty and single controller hierarchies`() {
        let split = UISplitViewController()
        #expect(split.topController === split)
        #expect(split.findController(destination: .identity(MockPushControllerNavigationIdentity())) == nil)

        let primary = UIViewController()
        split.viewControllers = [UINavigationController(rootViewController: primary)]
        #expect(split.topController === primary)
        #expect(split.isSingleNavigation)
    }

    @Test(arguments: [SplitStrategy.primary(action: .push), .secondary(action: .pop), .primary(action: .replace)])
    func `Column strategies on classic splits use fallback and release queued work`(strategy: SplitStrategy) async {
        let split = UISplitViewController()
        split.viewControllers = [UINavigationController(rootViewController: UIViewController()), UIViewController()]
        let window = UIWindow()
        window.rootViewController = split
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        var failures: [NavigationFailure.Reason] = []
        navigator.navigationFailureHandler = { failures.append($0.reason) }
        let fallback = UIViewController()
        let subsequent = UIViewController()
        let first = expectation(description: "classic split fallback")
        let queued = expectation(description: "navigation after classic split fallback")

        navigator.navigate(
            destination: .controller(UIViewController()),
            strategy: .split(strategy: strategy),
            animated: false,
            fallback: NavigationChainLink(destination: .controller(fallback), strategy: .replaceWindowRoot(), animated: false)
        ) { controller, success in
            #expect(controller === fallback)
            #expect(success)
            first.fulfill()
        }
        navigator.navigate(destination: .controller(subsequent), strategy: .replaceWindowRoot(), animated: false) { controller, success in
            #expect(controller === subsequent)
            #expect(success)
            queued.fulfill()
        }
        await fulfillment(of: [first, queued], timeout: 3)
        #expect(failures == [.splitColumnNavigationControllerUnavailable])
        #expect(window.rootViewController === subsequent)
    }
}
