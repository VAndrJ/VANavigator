//
//  ControllerViewProtocol.swift
//  SimpleExample
//
//  Created by VAndrJ on 13.02.2024.
//

import UIKit

protocol ControllerViewProtocol: UIView {
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
