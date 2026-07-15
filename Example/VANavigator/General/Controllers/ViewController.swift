//
//  ViewController.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import RxCocoa
import RxSwift
import VATextureKitRx

protocol NavigationClosable: UIViewController {
    var isNotImportant: Bool { get }
}

class ViewController<Node: ASDisplayNode & Responder & ControllerNode>: VAViewController<Node>, NavigationClosable, Responder {
    let bag = DisposeBag()
    let isNotImportant: Bool

    private let shouldHideNavigationBar: Bool

    init(node: Node, shouldHideNavigationBar: Bool = true, isNotImportant: Bool = false, title: String? = nil) {
        self.shouldHideNavigationBar = shouldHideNavigationBar
        self.isNotImportant = isNotImportant

        super.init(node: node)

        self.title = title
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        contentNode.viewDidLoad(in: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        contentNode.viewWillAppear(in: self, animated: animated)
        navigationController?.setNavigationBarHidden(shouldHideNavigationBar, animated: true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        contentNode.viewDidAppear(in: self, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        contentNode.viewWillDisappear(in: self, animated: animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        contentNode.viewDidDisappear(in: self, animated: animated)
    }

    // MARK: - Responder

    var nextEventResponder: (any Responder)? {
        get { contentNode }
        set { contentNode.nextEventResponder = newValue }
    }

    func handle(event: any ResponderEvent) async -> Bool {
        logResponder(from: self, event: event)

        return await nextEventResponder?.handle(event: event) ?? false
    }
}

class BaseViewController<View: UIView & ControllerViewProtocol & Responder>: UIViewController, Responder {
    let isNotImportant: Bool
    let contentView: View

    private let shouldHideNavigationBar: Bool

    init(
        view: View,
        shouldHideNavigationBar: Bool = true,
        isNotImportant: Bool = false,
        title: String? = nil
    ) {
        self.contentView = view
        self.shouldHideNavigationBar = shouldHideNavigationBar
        self.isNotImportant = isNotImportant

        super.init(nibName: nil, bundle: nil)

        self.title = title
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
