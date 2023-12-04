# VANavigator

[![Version](https://img.shields.io/cocoapods/v/VANavigator.svg?style=flat)](https://cocoapods.org/pods/VANavigator)
[![License](https://img.shields.io/cocoapods/l/VANavigator.svg?style=flat)](https://cocoapods.org/pods/VANavigator)
[![Platform](https://img.shields.io/cocoapods/p/VANavigator.svg?style=flat)](https://cocoapods.org/pods/VANavigator)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

Minimum deployment target: **iOS 13**

## Installation

VANavigator is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'VANavigator'
```

## Description


`VANavigator` is designed to simplify and streamline navigation in application, alleviating the complexities associated with searching for and transitioning to specific view controllers. 
At its core, `VANavigator` revolves around the concept of `NavigationIdentity`, a key element that enables the seamless discovery of the required view controller in `UIWindow`, facilitating easy navigation back to it or opening a new one based on the specified `NavigationStrategy`.


Navigation strategies:


- Replace `UIWindow` root view controller

Code example:
```
navigator.navigate(
    destination: .identity(MainNavigationIdentity()),
    strategy: .replaceWindowRoot()
)
```


- Present view controller 

Code example:
```
navigator?.navigate(
    destination: .identity(MainNavigationIdentity()),
    strategy: .present
)
```


- Present view controller or close all presented to existing

Code example:
```
navigator?.navigate(
    destination: .identity(MainNavigationIdentity()),
    strategy: .presentOrCloseToExisting
)
```


- Push view controller 

Code example:
```
navigator?.navigate(
    destination: .identity(MainNavigationIdentity()),
    strategy: .push()
)
```


- Push view controller or pop to existing

Code example:
```
navigator?.navigate(
    destination: .identity(MainNavigationIdentity()),
    strategy: .pushOrPopToExisting()
)
```


- Replace navigation stack with view controller or present.

Code example:
```
navigator?.navigate(
    destination: .identity(MainNavigationIdentity()),
    strategy: .replaceNavigationRoot()
)
```


- Under development


## Author

Volodymyr Andriienko, vandrjios@gmail.com

## License

VANavigator is available under the MIT license. See the LICENSE file for more info.
