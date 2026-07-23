//
//  PopoverDelegate.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 24.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

final class PopoverDelegate: NSObject, UIPopoverPresentationControllerDelegate {
    static let shared = PopoverDelegate()

    private override init() {}

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        .none
    }
}
