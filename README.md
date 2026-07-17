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
| Navigation queue serialization | Main → **Present queue example** |
| Interception and continuation after authorization | Main → **Open authorization-protected content** → **Login** |
| Nested fallback chain and responder event | Use the app's **Details** Home Screen quick action |

Generated responder events are shown at the bottom of the destination screen when applicable.


## Requirements


Minimum deployment target: **iOS 15**

Swift **6.2** or later.

Navigation identities, responder events, and navigation APIs are isolated to the main actor. Construct identities and events on the main actor before starting navigation.

`Responder.handle(event:)` is awaited before navigation completes and before queued work continues. Implementations must return after handling the event; start independent long-running work in a separate task instead of suspending the handler indefinitely.

Navigation stack mutations fail safely (and use their configured fallback) while UIKit is already performing a transition, or when the destination controller belongs to another view-controller/window hierarchy. Setting the first root controller also calls `makeKeyAndVisible()` on the navigator's window.

Controller lookup traverses custom-container children. UIKit has no generic active-child API for custom containers, so
`topController` treats the last non-dismissing child attached to a window as active. Applications whose custom
containers use different visibility semantics should avoid top-controller-based strategies for those containers.


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
