//
//  LoginScreen.swift
//  VANavigator_Example
//
//  Created by Volodymyr Andriienko on 04.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Observation
import ObservationTracking
import UIKit

final class LoginScreen: ControllerView<LoginViewModel> {
    private lazy var titlelabel = Label(
        text: "Login",
        textStyle: .headline
    )
    private lazy var replaceRootButton = Button(title: "Replace root with new main")
    private lazy var loginButton = Button(title: "Login")
    private lazy var descriptionLabel = Label(textStyle: .body)

    override func viewDidLoad(in controller: UIViewController) {
        controller.title = "Login"
    }

    override func addElements() {
        embedIntoScroll(
            titlelabel,
            Spacing(
                value: 32,
                child: loginButton
            ),
            Spacing(
                value: 16,
                child: replaceRootButton
            ),
            descriptionLabel
        )
    }

    override func configure() {
        backgroundColor = .systemBackground
    }

    override func bindView() {
        replaceRootButton.onTap = viewModel ?> { $0.perform(ReplaceRootWithNewMainEvent()) }
        loginButton.onTap = viewModel ?> { $0.perform(LoginEvent()) }
    }

    @ObservationTracking
    override func bindViewModel() {
        descriptionLabel.text = viewModel.openType
    }
}

private struct LoginEvent: Event {}

@Observable
final class LoginViewModel: EventViewModel {
    struct Context {
        struct DataSource {
            let authorize: () -> Void
        }

        struct Navigation {
            let followReplaceRootWithNewMain: () -> Void
        }

        let source: DataSource
        let navigation: Navigation
    }

    var openType = ""

    private let context: Context

    init(context: Context) {
        self.context = context

        super.init()
    }

    override func run(_ event: any Event) {
        switch event {
        case _ as LoginEvent:
            context.source.authorize()
        case _ as ReplaceRootWithNewMainEvent:
            context.navigation.followReplaceRootWithNewMain()
        default:
            super.run(event)
        }
    }

    override func handle(event: any ResponderEvent) async -> Bool {
        logResponder(from: self, event: event)
        switch event {
        case _ as ResponderOpenedFromShortcutEvent:
            openType = "Opened from shortcut"

            return true
        case _ as ResponderPoppedToExistingEvent:
            openType = "Popped to existing"

            return true
        default:
            return await nextEventResponder?.handle(event: event) ?? false
        }
    }
}
