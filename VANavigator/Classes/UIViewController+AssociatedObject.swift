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
    
    public var navigationIdentity: NavigationIdentity? {
        get {
            objc_getAssociatedObject(self, Self.key) as? NavigationIdentity
        }
        set {
            objc_setAssociatedObject(self, Self.key, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

@propertyWrapper
public class UniqueAddress {
    public var wrappedValue: UnsafeRawPointer { UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque()) }
    
    public init() {}
}
