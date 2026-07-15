//
//  ControllerNode.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 06.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import VATextureKit

@MainActor
protocol ControllerNode: ASDisplayNode {
    func viewDidLoad(in controller: UIViewController)
    func viewDidAppear(in controller: UIViewController, animated: Bool)
    func viewWillAppear(in controller: UIViewController, animated: Bool)
    func viewWillDisappear(in controller: UIViewController, animated: Bool)
    func viewDidDisappear(in controller: UIViewController, animated: Bool)
}
