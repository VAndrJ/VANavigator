//
//  ControllerView.swift
//  SimpleExample
//
//  Created by VAndrJ on 13.02.2024.
//

import UIKit

@MainActor
protocol ControllerViewProtocol: UIView {
    func viewDidLoad(in controller: UIViewController)
    func viewDidAppear(in controller: UIViewController, animated: Bool)
    func viewWillAppear(in controller: UIViewController, animated: Bool)
    func viewWillDisappear(in controller: UIViewController, animated: Bool)
    func viewDidDisappear(in controller: UIViewController, animated: Bool)
}

class ControllerView<ViewModel: EventViewModel>: UIView, ControllerViewProtocol, Responder {
    var embedded: UIViewController { ViewController(view: self) }

    func embedded(
        shouldHideNavigationBar: Bool = true,
        isNotImportant: Bool = false,
        title: String? = nil,
        tabBarItem: UITabBarItem? = nil
    ) -> UIViewController {
        let controler = ViewController(
            view: self,
            shouldHideNavigationBar: shouldHideNavigationBar,
            isNotImportant: isNotImportant,
            title: title
        )
        if let tabBarItem {
            controler.tabBarItem = tabBarItem
        }

        return controler
    }

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

    var nextEventResponder: (any Responder)? {
        get { viewModel }
        set { viewModel.nextEventResponder = newValue }
    }

    func handle(event: any ResponderEvent) async -> Bool {
        logResponder(from: Self.self, event: event)

        return await nextEventResponder?.handle(event: event) ?? false
    }
}

struct BecomeVisibleEvent: Event {}

protocol Event: Sendable {}

class EventViewModel: ViewModel {
    weak var controller: UIViewController?

    func run(_ event: any Event) async {
        #if DEBUG || targetEnvironment(simulator)
        print("⚠️ [Event not handled] \(event)")
        #endif
    }

    final func perform(_ event: any Event) {
        Task { @MainActor in
            await run(event)
        }
    }
}

@MainActor
class ViewModel: NSObject, Responder {

    // MARK: - Responder

    weak var nextEventResponder: (any Responder)?

    func handle(event: any ResponderEvent) async -> Bool {
        logResponder(from: Self.self, event: event)

        return await nextEventResponder?.handle(event: event) ?? false
    }
}
