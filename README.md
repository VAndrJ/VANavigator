# VANavigator


[![StandWithUkraine](https://raw.githubusercontent.com/vshymanskyy/StandWithUkraine/main/badges/StandWithUkraine.svg)](https://github.com/vshymanskyy/StandWithUkraine/blob/main/docs/README.md)
[![Support Ukraine](https://img.shields.io/badge/Support-Ukraine-FFD500?style=flat&labelColor=005BBB)](https://opensource.fb.com/support-ukraine)


[![Language](https://img.shields.io/badge/language-Swift%206.2-orangered.svg?style=flat)](https://www.swift.org)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-iOS%2015%2B-lightgrey.svg)](Package.swift)


[![SPM](https://img.shields.io/badge/SPM-compatible-limegreen.svg?style=flat)](https://github.com/apple/swift-package-manager)
&nbsp;[![VANavigator](https://github.com/VAndrJ/VANavigator/actions/workflows/swift.yml/badge.svg)](https://github.com/VAndrJ/VANavigator/actions/workflows/swift.yml)

VANavigator is a UIKit navigation library. It helps you find an existing screen or open a new one
without manually searching the view-controller hierarchy.

Use it with navigation stacks, tabs, split views, modal presentations, and adaptive arrangements.
You can combine navigation steps, provide fallbacks, and pause navigation for tasks such as login.

## Requirements

- iOS 15 or later.
- Swift 6.2 or later.

Use navigation APIs, identities, and responder events on the main actor.
Adaptive arrangement support requires Xcode 27.1 or later and iOS 27.1 or later.

## Installation

Add this repository in Xcode under **Package Dependencies**:

```text
https://github.com/VAndrJ/VANavigator.git
```

## Getting started

Each navigation request has two parts: a **destination** (which screen) and a **strategy** (how to reach it).

To use identities, your app provides:

- A `NavigationIdentity` for each kind of screen. Its `isEqual(to:)` method determines whether two identities
  refer to the same screen, such as the details screen for the same item.
- A `NavigatorScreenFactory` that implements `assembleScreen(identity:navigator:)` to build a screen from its identity.

The code below assumes you have defined `MainNavigationIdentity` and `AppScreenFactory`.
See the example app's [identities](Example/VANavigator/App/NavigationIdentity+VANavigatorExample.swift) and
[screen factory](Example/VANavigator/App/ScreenFactory.swift) for implementations.

Create and retain a `Navigator` for each scene's window. This example starts with a navigation controller,
then opens the main screen inside it:

```swift
import UIKit
import VANavigator

let navigator = Navigator(
    window: window,
    screenFactory: AppScreenFactory()
)

navigator.navigate(
    destination: .controller(UINavigationController()),
    strategy: .replaceWindowRoot()
)

navigator.navigate(
    destination: .identity(MainNavigationIdentity()),
    strategy: .push()
)
```

Strategies such as `.popToExisting()` look for a matching identity. Strategies such as `.push()` ask the factory
to create a new controller. The navigator assigns the identity to the controller returned by the factory.

You can also pass a view controller directly. This skips the factory and uses that exact instance:

```swift
navigator.navigate(
    destination: .controller(detailsViewController),
    strategy: .push()
)
```

Set a controller's `navigationIdentity` if you also want to find it by identity.
Pass `animated: false` to disable animations. The optional `completion` receives the result controller and a `Bool`
indicating whether navigation succeeded, including any fallback.

## Navigation strategies

Choose a strategy to tell the navigator how to reach the destination:

| Strategy | What it does |
| --- | --- |
| `.replaceWindowRoot()` | Sets or replaces the window's root controller. |
| `.present()` | Presents a controller modally. |
| `.popover(configure:)` | Presents a popover using the anchor you provide. |
| `.push()` | Pushes a controller onto the current navigation stack. |
| `.popToExisting()` | Pops a navigation stack back to an existing screen, searching across tabs by default. |
| `.closeToExisting` | Finds an existing screen anywhere in the window, dismisses screens above it, and reveals it. |
| `.replaceNavigationRoot` | Replaces the current navigation stack with one controller. |
| `.closeIfTop()` | Pops or dismisses the destination if it is the top screen. |
| `.removeFromNavigationStack` | Removes a controller from the current stack, but never removes its only controller. |
| `.split(strategy: .secondary(action: .push))` | Pushes a controller into the secondary split-view column. |

For split navigation, choose `.primary(action:)` or `.secondary(action:)` with `.push`, `.pop`, or `.replace`.
Use `.popToExisting(includingTabs: false)` to skip other tabs during lookup.

Use `.present(source:)` to present from the top controller, navigation controller, or tab bar controller.
The available sources are `.topController`, `.navigationController`, and `.tabBarController`.

For a popover, provide a source view or bar item:

```swift
navigator.navigate(
    destination: .identity(MainNavigationIdentity()),
    strategy: .popover { popover, _ in
        popover.sourceView = sourceView
    }
)
```

The presenting controller's view must be attached to the navigator's visible window.
Split-column strategies require a `UISplitViewController` created with `init(style:)`.
The navigator can also find screens inside classic split views.

To animate window-root replacement, pass a `CATransition` to `.replaceWindowRoot(transition:)`.
The transition must start immediately and finish after one pass; paused, delayed, and repeating transitions are rejected.

## Fallbacks and navigation chains

Fallbacks let you try another strategy when the first one cannot complete. For example, return to an existing
screen, push a new one if it is missing, or present it if there is no navigation stack:

```swift
navigator.navigate(
    destination: .identity(MainNavigationIdentity()),
    strategy: .popToExisting(),
    fallbackStrategies: [.push(), .present()]
)
```

Use `fallback: NavigationChainLink(...)` when a fallback needs a different destination.
Use `navigate(chain:)` with an array of `NavigationChainLink` values to perform several steps in order.
A chain stops if a step fails and its fallbacks cannot complete.

Navigation requests run one at a time. The next request waits for the current transition and responder event handling.
If UIKit is already transitioning, or a destination belongs to an incompatible controller hierarchy,
the navigator reports failure and tries the configured fallback.

## Responder events

Define a `ResponderEvent` and pass it as `event` to `navigate` to send information to a destination
that implements [`Responder`](VANavigator/Classes/Responder.swift).
The navigator also sends events when returning to an existing controller or replacing the window root.

The navigator waits for `Responder.handle(event:)` before calling completion and continuing queued navigation.
Keep handlers brief; start independent long-running work in a separate task.

## Navigation interception

Subclass `NavigationInterceptor` to pause navigation when a condition must be met first, such as signing in.
Override `intercept(destination:)` to return a `NavigationInterceptionResult` with the steps to show instead
(for example, a login screen) and a reason that identifies why navigation is waiting.

After resolving the condition, call `interceptionResolved(reason:completion:)` with the same reason to resume navigation.
If several requests share that reason, all resume, and the resolution succeeds only if they all succeed.
Use `removeIfAvailable(reason:)` or `removeAllReasons()` to cancel waiting requests; their completions receive `(nil, false)`.

## Failure diagnostics

Use `navigationFailureHandler` to log why an attempt failed:

```swift
navigator.navigationFailureHandler = { failure in
    print("Navigation failed: \(failure.reason.rawValue)")
}
```

The failure includes its reason, destination, and strategy. The handler runs before a fallback is tried,
so you can receive a diagnostic even when the fallback succeeds.

## iOS 27.1 and iPhone Duo

VANavigator supports `UIArrangementViewController` on iOS 27.1 and later. It finds controllers in both visible
and hidden panels, and `topController` follows the frontmost visible panel. Returning to a hidden panel fails
unless your app makes it visible; the navigator leaves arrangement layout decisions to your app.
The `.split` strategies apply to `UISplitViewController`.

Place a navigation controller around the arrangement when pushing a screen should replace the whole layout:

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

Arrangement support is excluded from Mac Catalyst because of a known issue in
[Xcode 27.1](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes).
The rest of the library still supports older iOS versions and SDKs.

For layout guidance and advice on combining containers, see Apple's
[arrangement documentation](https://developer.apple.com/documentation/uikit/uiarrangementviewcontroller) and
[iPhone Duo preparation guide](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo).

## Custom containers

The navigator also searches child controllers inside custom containers. To choose `topController`, it uses the last
child attached to a window that is not being dismissed. If none is attached, it uses the last child not being dismissed.
If your container uses a different rule for its active child, avoid strategies that depend on `topController`.

## Example app

Clone the repository and open `Example/VANavigator.xcodeproj`. Xcode resolves its package dependencies automatically.
The example requires iOS 17 or later; its arrangement screens require iOS 27.1 or later.

| Try | Where to find it |
| --- | --- |
| Root replacement | Main → **Replace root with new main** |
| Push, pop, close, and stack changes | Main → **Open details** |
| Tabs, modal presentations, and popovers | Main → **Open tabs** → **Present** tab |
| Split-column navigation | Main → **Open split** |
| Adaptive arrangements | Main → **Open adaptive arrangement** or **Replace root with adaptive arrangement** |
| Queued navigation | Main → **Present queue example** |
| Login interception | Main → **Open authorization-protected content** → **Login** |
| Fallback chains and events | The app's **Details** Home Screen quick action |

Responder events appear at the bottom of the destination screen when applicable.

## Author

Volodymyr Andriienko, vandrjios@gmail.com

## License

VANavigator is available under the MIT license. See [LICENSE](LICENSE).
