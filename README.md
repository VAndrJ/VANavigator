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


## Requirements


Minimum deployment target: **iOS 15**

Swift **6.2** or later.

Navigation identities, responder events, and navigation APIs are isolated to the main actor. Construct identities and events on the main actor before starting navigation.


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


## Author


Volodymyr Andriienko, vandrjios@gmail.com


## License


VANavigator is available under the MIT license. See the LICENSE file for more info.
