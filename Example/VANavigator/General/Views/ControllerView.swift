//
//  ControllerView.swift
//  VANavigator
//
//  Created by VAndrJ on 15.07.2026.
//  Copyright © 2026 Volodymyr Andriienko. All rights reserved.
//

import UIKit

@MainActor
protocol ScreenProtocol: UIView {
    func viewDidLoad(in controller: UIViewController)
    func viewDidAppear(in controller: UIViewController, animated: Bool)
    func viewWillAppear(in controller: UIViewController, animated: Bool)
    func viewWillDisappear(in controller: UIViewController, animated: Bool)
    func viewDidDisappear(in controller: UIViewController, animated: Bool)
}

class ControllerView<ViewModel: EventViewModel>: UIView, ScreenProtocol, Responder {
    let viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel

        super.init(frame: .init(x: 0, y: 0, width: 320, height: 568))

        addElements()
        configure()
        bind()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addElements() {}

    func configure() {}

    private func bind() {
        bindView()
        bindViewModel()
    }

    func bindView() {}

    func bindViewModel() {}

    // MARK: - ControllerViewProtocol

    func viewDidLoad(in controller: UIViewController) {
        viewModel.controller = controller
    }

    func viewDidAppear(in controller: UIViewController, animated: Bool) {}

    func viewWillAppear(in controller: UIViewController, animated: Bool) {}

    func viewWillDisappear(in controller: UIViewController, animated: Bool) {}

    func viewDidDisappear(in controller: UIViewController, animated: Bool) {}

    // MARK: - Responder

    var nextEventResponder: (any Responder)? {
        get { viewModel }
        set { viewModel.nextEventResponder = newValue }
    }

    func handle(event: any ResponderEvent) async -> Bool {
        logResponder(from: Self.self, event: event)

        return await nextEventResponder?.handle(event: event) ?? false
    }
}
