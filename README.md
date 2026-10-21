# VANavigator


[![StandWithUkraine](https://raw.githubusercontent.com/vshymanskyy/StandWithUkraine/main/badges/StandWithUkraine.svg)](https://github.com/vshymanskyy/StandWithUkraine/blob/main/docs/README.md)
[![Support Ukraine](https://img.shields.io/badge/Support-Ukraine-FFD500?style=flat&labelColor=005BBB)](https://opensource.fb.com/support-ukraine)


[![Language](https://img.shields.io/badge/language-Swift%206.2-orangered.svg?style=flat)](https://www.swift.org)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-iOS%2015%2B-lightgrey.svg)](Package.swift)


[![SPM](https://img.shields.io/badge/SPM-compatible-limegreen.svg?style=flat)](https://github.com/apple/swift-package-manager)
&nbsp;[![VANavigator](https://github.com/VAndrJ/VANavigator/actions/workflows/swift.yml/badge.svg)](https://github.com/VAndrJ/VANavigator/actions/workflows/swift.yml)


## Example


To run the example project, clone the repo and open `Example/VANavigator.xcodeproj`. Xcode resolves its Swift package dependencies automatically.
The example and its test host require iOS 17 or later; the library supports iOS 15 or later.

The example is organized as a set of reproducible navigation flows:

| Feature | Path in the example |
| --- | --- |
| Replace the window root, including a transition | Main → **Replace root with new main** |
| Present from the top, navigation, or tab bar controller | Main → **Open tabs** → **Present** tab |
| Present a popover | Main → **Open tabs** → **Present** tab → **Present popover** |
| Pop to an existing controller or push a new one | Main → **Open details** → enter one or more numbers |
| Close to an existing controller | Main → **Open details** → **Close presented screens to existing Main** |
| Replace a navigation stack root | Main → **Open details** → **Replace navigation root with Details 0** |
| Close the top controller by popping or dismissing | Main → **Open details** → **Close this top screen** |
| Remove a controller from a navigation stack | Main → **Open details** → push another number → **Remove -1 from navigation stack** |
| Split push, pop, and replace | Main → **Open split** → use the buttons in **Primary**; the push/pop chain is easiest to observe on iPad |
| Adaptive arrangement layout (iOS 27.1+) | Main → **Open adaptive arrangement** → switch split/overlay or limit the axis; type in both panels, resize, push a detail, and return |
| Arrangement as the window root (iOS 27.1+) | Main → **Replace root with adaptive arrangement** → push a detail inside the frontmost panel, return, or choose **Main** to replace the root again |
| Navigation queue serialization | Main → **Present queue example** |
| Interception and continuation after authorization | Main → **Open authorization-protected content** → **Login** |
| Nested fallback chain and responder event | Use the app's **Details** Home Screen quick action |

Generated responder events are shown at the bottom of the destination screen when applicable.


## Requirements


Minimum deployment target: **iOS 15**

Swift **6.2** or later.

Navigation identities, responder events, and navigation APIs are isolated to the main actor. Construct identities and events on the main actor before starting navigation.

`Responder.handle(event:)` is awaited before navigation completes and before queued work continues. Implementations must return after handling the event; start independent long-running work in a separate task instead of suspending the handler indefinitely.
Returning through nested navigation stacks completes pending window layout before delivering responder events.

Programmatic tab selection waits for UIKit's selection transition before its completion and queued navigation run.
This also applies to tabs revealed by `.closeToExisting` and `.popToExisting()`, including nested tab containers.

Navigation stack mutations fail safely (and use their configured fallback) while UIKit is already performing a transition, or when the destination controller belongs to another view-controller/window hierarchy. Setting the first root controller also calls `makeKeyAndVisible()` on the navigator's window.

Modal and popover presentations require a source view attached to the navigator's visible window. An unavailable
source fails with `sourceViewControllerUnavailable`, allowing fallback and queued navigation to continue.

Window-root `CATransition` values must start immediately and finish after one finite pass. Paused, delayed,
time-offset, or repeating transitions fail with `invalidTransitionConfiguration` so they cannot block queued navigation.

Controller lookup traverses custom-container children. UIKit has no generic active-child API for custom containers, so
`topController` treats the last non-dismissing child attached to a window as active. Applications whose custom
containers use different visibility semantics should avoid top-controller-based strategies for those containers.

Controller lookup supports classic `UISplitViewController` instances. The `.split` strategies and
`columnNavigationController(for:)` require a column-style split view created with `init(style:)`.
On a classic split view, column strategies report `splitColumnNavigationControllerUnavailable` and use their fallback.
Lookup also searches assigned columns while they are hidden or collapsed. `.closeToExisting` and `.popToExisting()`
reveal the target's containing tabs, split columns, and enclosing navigation stacks before delivering responder events.

## iOS 27.1 and iPhone Duo

Build with Xcode 27.1 (Swift 6.4) and the iOS 27.1 SDK or newer to enable `UIArrangementViewController` integration.
The package still supports iOS 15 and Swift 6.2 with older SDKs; arrangement code is guarded at compile time and runtime.
It is excluded from Mac Catalyst to work around the iOS 27.1 API compilation issue documented in Apple's
[Xcode 27.1 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes).

Arrangement views control layout. Keep the `UINavigationController` outside the arrangement when navigation should
replace the whole layout:

```swift
#if canImport(UIKit.UIArrangementViewController) && !targetEnvironment(macCatalyst)
if #available(iOS 27.1, *) {
    let arrangement = UIArrangementViewController()
    arrangement.setViewController(primary, for: .primary)
    arrangement.setViewController(secondary, for: .secondary)
    arrangement.updateArrangement(.split.axes(.horizontal))
    navigator.navigate(
        destination: .controller(UINavigationController(rootViewController: arrangement)),
        strategy: .present()
    )
}
#endif
```

`topController` follows the frontmost visible placement using UIKit's `ViewState` and the installed view hierarchy.
Equal stacking levels prefer primary, including before the first layout. Identity lookup searches visible placements
first, then retained hidden placements. Instance lookup also finds retained content.
`.closeToExisting`, `.popToExisting`, and split-column pop validate arrangement visibility after revealing the enclosing
navigation stack. A destination that remains hidden fails with `mutationRejected`, allowing fallback and queued work to
continue without delivering a successful navigation event. Configure the arrangement in your app if you need to reveal that placement;
the navigator does not change the app's preferred arrangement or axes. `.split` strategies continue to apply only to
`UISplitViewController`.

Prefer navigation around the arrangement for new layouts. Apple's
[arrangement API guidance](https://developer.apple.com/documentation/uikit/uiarrangementviewcontroller) advises against
nesting arrangements in split views, scroll views, or collection views, and against placing split or tab containers
inside arrangements. The window-root example demonstrates independent panel navigation; choose that composition
only when panel-local stacks are part of your app's design. Lookup support for a nested hierarchy does not guarantee
that every container composition will lay out well in every Duo pose.

Create one navigator for each scene's window, as the example's `SceneDelegate` does. Apps built with the latest SDK
on iOS 27 must use the [scene-based lifecycle](https://developer.apple.com/documentation/uikit/transitioning-to-the-uikit-scene-based-life-cycle).
Use the current view's bounds, safe areas, and traits for layout decisions. Do not infer available space from the
device model, screen size, interface idiom, or orientation.

The example uses standard navigation and toolbar items with both titles and symbols so UIKit can adapt them to
vertical bars. Its prominent Done/Main action uses `UINavigationItem.pinnedTrailingGroup` to stay out of the overflow
menu when space is limited. Custom containers and custom controls remain responsible for reserved regions, camera occlusions,
keyboard avoidance, and accessibility. See Apple's [Duo preparation guide](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)
and [Duo design guidance](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo).

For a custom layout, inspect `UIView.reservedRegions(kind:options:)` and each region's active state as the fold or
camera changes. Safe-area insets alone do not describe every division or occlusion. Use
`traitCollection.verticalBarEdge` when custom content needs to adapt to a vertical bar, and let
`UISheetPresentationController.preferredPlacement` express a sheet's preferred placement instead of fixed coordinates.

The example's scroll views follow `keyboardLayoutGuide`. During editing, its split arrangement gives the focused
panel a larger preferred share, then restores equal sizing when editing ends. Draft fields support Dynamic Type.
These are example layout choices; the navigator continues to leave arrangement policy to the app.

### Verification

With Xcode 27.1+ and an installed iOS 27.1 Duo simulator, run:

```sh
xcodebuild -project Example/VANavigator.xcodeproj -scheme VANavigator-Example \
  -destination 'platform=iOS Simulator,OS=27.1,name=iPhone Duo' \
  -skipMacroValidation build test
```

The regression suite covers classic and collapsed split lookup, invalid stack destinations, arrangement stacking,
repeated layout resizing, retained hidden content, fallback/queue behavior, and navigation outside the arrangement.
Hosted CI retains the older SDK/runtime lanes and adds a Duo lane on the `xcode-27` runner with Xcode 27.1.
That lane installs the iOS 27.1 runtime if needed and creates a dedicated `VANavigator Duo` simulator before testing.

Also check the adaptive example on outer, fully open, and partially folded displays in both orientations. Verify that
typed text survives transitions, controls remain reachable with the keyboard and larger text, sheets/popovers keep
their anchors, and interactive back/dismiss cancellation leaves navigation usable. Automated size/trait tests do not
replace device pose testing.


## Installation


VANavigator is available through [SPM](https://github.com/apple/swift-package-manager). To install
it, simply add to your Package Dependencies:


```
https://github.com/VAndrJ/VANavigator.git
```


## Description


`VANavigator` is designed to simplify and streamline navigation in an application, alleviating the complexities associated with searching for and transitioning to specific view controllers. 
At its core, `VANavigator` revolves around the concept of `NavigationIdentity`, a key element that enables the seamless discovery of the required view controller in `UIWindow`, facilitating easy navigation back to it or opening a new one based on the specified `NavigationStrategy`.


**Navigation strategies:**


- Replace `UIWindow` root view controller.


Code example:
```
navigator.navigate(
    destination: .identity(MainNavigationIdentity()),
    strategy: .replaceWindowRoot()
)
```


- Present view controller.


Code example:
```
navigator.navigate(
    destination: .identity(MainNavigationIdentity()),
    strategy: .present()
)
```

Choose the presentation container with `.present(source:)`. Available sources are `.topController`, `.navigationController`, and `.tabBarController`.


- Present a popover.


Code example:
```
navigator.navigate(
    destination: .identity(MainNavigationIdentity()),
    strategy: .popover { popover, _ in
        popover.sourceView = sourceView
    }
)
```


- Closes presented controllers to the given controller if it exists.


Code example:
```
navigator.navigate(
    destination: .identity(MainNavigationIdentity()),
    strategy: .closeToExisting
)
```


- Push view controller.


Code example:
```
navigator.navigate(
    destination: .identity(MainNavigationIdentity()),
    strategy: .push()
)
```


- Remove an existing controller from a navigation stack.


Code example:
```
navigator.navigate(
    destination: .identity(MainNavigationIdentity()),
    strategy: .removeFromNavigationStack
)
```


- Pops to existing controller in `UINavigationController`'s navigation stack.


Code example:
```
navigator.navigate(
    destination: .identity(MainNavigationIdentity()),
    strategy: .popToExisting()
)
```


- Replace the `UINavigationController`'s navigation stack with a new controller.

Code example:
```
navigator.navigate(
    destination: .identity(MainNavigationIdentity()),
    strategy: .replaceNavigationRoot
)
```


- Close (pop or dismiss) the controller if it is the top one.


Code example:
```
navigator.navigate(
    destination: .identity(MainNavigationIdentity()),
    strategy: .closeIfTop()
)
```


- Shows in a `UISplitViewController` with the given `strategy`.


Code example:
```
navigator?.navigate(
    destination: .identity(MainNavigationIdentity()),
    strategy: .split(strategy: ...)
)
```


**Navigation interception**


Use the `NavigationInterceptor` to intercept the navigation flow and replace it with a new one based on the provided conditions. Continue the intercepted navigation after resolving the interception reason.

Removing an interception reason cancels its pending navigations and completes each one with `(nil, false)`.

Resolving a reason resumes all of its pending navigations. The resolution completion waits for all of them and
reports success only when every resumed navigation succeeds. It returns the last submitted navigation's result
controller; each navigation also receives its own completion result.


**Failure diagnostics**


Navigation completion handlers keep their existing success/failure values. For production logging, assign
`navigationFailureHandler` to receive the typed reason, destination, and strategy for every rejected attempt:

```swift
navigator.navigationFailureHandler = { failure in
    print("Navigation failed: \(failure.reason.rawValue)")
}
```

The handler runs on the main actor before a configured fallback is attempted. A failed primary strategy therefore
produces a diagnostic even when its fallback later completes the overall navigation successfully. The handler is
optional and does not change queueing, completion, or fallback behavior.


## Author


Volodymyr Andriienko, vandrjios@gmail.com


## License


VANavigator is available under the MIT license. See the LICENSE file for more info.
