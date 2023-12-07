//
//  ControllerNode.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 06.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import VATextureKit

protocol ControllerNode: ASDisplayNode {

    @MainActor
    func viewDidLoad(in controller: UIViewController)
    @MainActor
    func viewDidAppear(in controller: UIViewController, animated: Bool)
    @MainActor
    func viewWillAppear(in controller: UIViewController, animated: Bool)
    @MainActor
    func viewWillDisappear(in controller: UIViewController, animated: Bool)
    @MainActor
    func viewDidDisappear(in controller: UIViewController, animated: Bool)
}
