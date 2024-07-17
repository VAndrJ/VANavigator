//
//  LoginScreenView.swift
//  SimpleExample
//
//  Created by VAndrJ on 13.02.2024.
//

import UIKit

class LoginScreenView: ControllerView<LoginViewModel> {
    private let titleLabel = UILabel().apply {
        $0.text = "Login screen"
    }
    private let loginButton = Button(title: "Login")

    override func addElements() {
        embedIntoScroll(
            titleLabel,
            loginButton
        )
    }

    override func configure() {
        backgroundColor = .systemBackground
    }

    override func bindView() {
        loginButton.onTap = viewModel ?> { $0.perform(LoginEvent()) }
    }
}

struct LoginEvent: Event {}

class LoginViewModel: EventViewModel {
    struct Context {
        struct Related {
        }

        struct DataSource {
            let authorize: () -> Void
        }

        struct Navigation {
        }

        let related: Related
        let source: DataSource
        let navigation: Navigation
    }

    private let data: Context

    init(data: Context) {
        self.data = data
    }

    override func run(_ event: any Event) async {
        switch event {
        case _ as LoginEvent:
            data.source.authorize()
        default:
            await super.run(event)
        }
    }

    override func handle(event: any ResponderEvent) async -> Bool {
        logResponder(from: Self.self, event: event)
        switch event {
        case _ as ResponderOpenedFromShortcutEvent:
            return true
        case _ as ResponderReplacedWindowRootControllerEvent:
            return true
        default:
            return await nextEventResponder?.handle(event: event) ?? false
        }
    }
}
