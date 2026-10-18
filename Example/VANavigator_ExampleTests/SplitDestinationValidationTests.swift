import Testing
import UIKit
import VANavigator

@Suite(.serialized)
final class SplitDestinationValidationTests {
    @Test(arguments: 0..<6, [false, true])
    func `Stack strategies reject split destinations before invoking UIKit`(strategyIndex: Int, classic: Bool) async {
        let strategies: [NavigationStrategy] = [
            .push(), .replaceNavigationRoot,
            .split(strategy: .primary(action: .push)),
            .split(strategy: .secondary(action: .push)),
            .split(strategy: .primary(action: .replace)),
            .split(strategy: .secondary(action: .replace)),
        ]
        let primary = SplitDestinationRecordingNavigationController(rootViewController: UIViewController())
        let secondary = SplitDestinationRecordingNavigationController(rootViewController: UIViewController())
        let split = UISplitViewController(style: .doubleColumn)
        split.setViewController(primary, for: .primary)
        split.setViewController(secondary, for: .secondary)
        let window = UIWindow()
        window.rootViewController = split
        let navigator = Navigator(window: window, screenFactory: MockScreenFactory())
        let destination = classic ? UISplitViewController() : UISplitViewController(style: .doubleColumn)
        let fallback = UIViewController()
        let subsequent = UIViewController()
        var failures: [NavigationFailure] = []
        navigator.navigationFailureHandler = { failures.append($0) }
        let rejected = expectation(description: "split destination fallback")
        let queued = expectation(description: "navigation after rejected split destination")
        navigator.navigate(
            destination: .controller(destination),
            strategy: strategies[strategyIndex],
            animated: false,
            fallback: NavigationChainLink(destination: .controller(fallback), strategy: .replaceWindowRoot(), animated: false)
        ) { controller, success in
            #expect(controller === fallback)
            #expect(success)
            rejected.fulfill()
        }
        navigator.navigate(destination: .controller(subsequent), strategy: .replaceWindowRoot(), animated: false) { controller, success in
            #expect(controller === subsequent)
            #expect(success)
            queued.fulfill()
        }
        await fulfillment(of: [rejected, queued], timeout: 3)
        #expect(failures.map(\.reason) == [.invalidDestinationHierarchy])
        #expect(failures.first?.strategy == strategies[strategyIndex])
        #expect(primary.splitMutationAttempts == 0)
        #expect(secondary.splitMutationAttempts == 0)
        #expect(destination.parent == nil)
        #expect(window.rootViewController === subsequent)
    }
}

private final class SplitDestinationRecordingNavigationController: UINavigationController {
    private(set) var splitMutationAttempts = 0

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        guard !(viewController is UISplitViewController) else {
            splitMutationAttempts += 1
            return
        }
        super.pushViewController(viewController, animated: animated)
    }

    override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
        guard !viewControllers.contains(where: { $0 is UISplitViewController }) else {
            splitMutationAttempts += 1
            return
        }
        super.setViewControllers(viewControllers, animated: animated)
    }
}
