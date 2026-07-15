//
//  UIViewController+AssociatedObject.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 18.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

extension UIViewController {
    @UniqueAddress static var key

    /// Stores and retrieves the navigation identity associated with the view controller.
    /// - The identity is stored using Objective-C runtime association with a unique key.
    /// - When set, the value is retained non-atomically.
    public var navigationIdentity: (any NavigationIdentity)? {
        get { objc_getAssociatedObject(self, Self.key) as? (any NavigationIdentity) }
        set { objc_setAssociatedObject(self, Self.key, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

@propertyWrapper
final class UniqueAddress {
    var wrappedValue: UnsafeRawPointer { UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque()) }

    init() {}
}
