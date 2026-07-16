//
//  ViewController.swift
//  VANavigator_Example
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

protocol NavigationClosable: UIViewController {
    var isNotImportant: Bool { get }
}

class ViewController<Screen: UIView & ScreenProtocol & Responder>: UIViewController, NavigationClosable, Responder {
    let isNotImportant: Bool
    let contentView: Screen

    private let shouldHideNavigationBar: Bool

    init(
        screen: Screen,
        shouldHideNavigationBar: Bool = true,
        isNotImportant: Bool = false,
        title: String? = nil
    ) {
        self.contentView = screen
        self.shouldHideNavigationBar = shouldHideNavigationBar
        self.isNotImportant = isNotImportant

        super.init(nibName: nil, bundle: nil)

        self.title = title
        hideKeyboardOnTapAround()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = contentView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        contentView.viewDidLoad(in: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        contentView.viewWillAppear(in: self, animated: animated)
        navigationController?.setNavigationBarHidden(shouldHideNavigationBar, animated: true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        contentView.viewDidAppear(in: self, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        contentView.viewWillDisappear(in: self, animated: animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        contentView.viewDidDisappear(in: self, animated: animated)
    }

    // MARK: - Responder

    var nextEventResponder: (any Responder)? {
        get { contentView }
        set { contentView.nextEventResponder = newValue }
    }

    func handle(event: any ResponderEvent) async -> Bool {
        logResponder(from: Self.self, event: event)

        return await nextEventResponder?.handle(event: event) ?? false
    }
}
