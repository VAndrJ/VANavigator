//
//  ControllerView.swift
//  SimpleExample
//
//  Created by VAndrJ on 13.02.2024.
//

import UIKit

class ControllerView<ViewModel: EventViewModel>: UIView, ControllerViewProtocol, Responder {
    let viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel

        super.init(frame: CGRect(x: 0, y: 0, width: 320, height: 568))

        addElements()
        configure()
        bind()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bindView() {}

    private func bind() {
        bindView()
    }

    func configure() {}

    func addElements() {}

    // MARK: - ControllerViewProtocol

    func viewDidLoad(in controller: UIViewController) {
        viewModel.controller = controller
    }

    func viewDidAppear(in controller: UIViewController, animated: Bool) {}

    func viewWillAppear(in controller: UIViewController, animated: Bool) {}

    func viewWillDisappear(in controller: UIViewController, animated: Bool) {}

    func viewDidDisappear(in controller: UIViewController, animated: Bool) {}

    // MARK: - Responder

    var nextEventResponder: Responder? {
        get { viewModel }
        set { viewModel.nextEventResponder = newValue }
    }

    func handle(event: ResponderEvent) async -> Bool {
        logResponder(from: Self.self, event: event)

        return await nextEventResponder?.handle(event: event) ?? false
    }
}
