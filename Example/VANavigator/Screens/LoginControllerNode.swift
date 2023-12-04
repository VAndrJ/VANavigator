//
//  LoginControllerNode.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 04.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import VATextureKitRx

class LoginControllerNode: DisplayNode<LoginViewModel> {
    private let titleTextNode = VATextNode(
        text: "Login",
        fontStyle: .headline
    )
    private let replaceRootButtonNode = VAButtonNode()
    private let loginButtonNode = VAButtonNode()
    private let descriptionTextNode = VATextNode(
        text: "",
        fontStyle: .body
    )

    override init(viewModel: LoginViewModel) {
        super.init(viewModel: viewModel)

        bind()
    }

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        SafeArea {
            Column(spacing: 16, cross: .stretch) {
                titleTextNode
                loginButtonNode
                replaceRootButtonNode
                    .padding(.top(32), .bottom(16))
                descriptionTextNode
            }
            .padding(.all(16))
        }
    }

    override func viewDidLoad(in controller: UIViewController) {
        controller.title = "Login"
    }

    override func configureTheme(_ theme: VATheme) {
        backgroundColor = theme.systemBackground
        replaceRootButtonNode.setTitle("Replace root with new main", theme: theme)
        loginButtonNode.setTitle("Login", theme: theme)
    }

    private func bind() {
        bindView()
        bindViewModel()
    }

    private func bindView() {
        replaceRootButtonNode.onTap = viewModel ?> { $0.perform(ReplaceRootWithNewMainEvent()) }
        loginButtonNode.onTap = viewModel ?> { $0.perform(LoginEvent()) }
    }

    private func bindViewModel() {
        viewModel.descriptionObs
            .bind(to: descriptionTextNode.rx.text)
            .disposed(by: bag)
    }
}

struct LoginEvent: Event {}

class LoginViewModel: EventViewModel {
    struct DTO {
        struct DataSource {
            let authorize: () -> Void
        }
        
        struct Navigation {
            let followReplaceRootWithNewMain: () -> Void
        }

        let source: DataSource
        let navigation: Navigation
    }

    @Obs.Relay(value: "Normally opened")
    var descriptionObs: Observable<String>

    private let data: DTO

    init(data: DTO) {
        self.data = data

        super.init()
    }

    override func run(_ event: Event) {
        switch event {
        case _ as LoginEvent:
            data.source.authorize()
        case _ as ReplaceRootWithNewMainEvent:
            data.navigation.followReplaceRootWithNewMain()
        default:
            super.run(event)
        }
    }

    override func handle(event: ResponderEvent) async -> Bool {
        logResponder(from: self, event: event)
        switch event {
        case _ as ResponderOpenedFromShortcutEvent:
            _descriptionObs.rx.accept("Opened from shortcut")

            return true
        case _ as ResponderPoppedToExistingEvent:
            _descriptionObs.rx.accept("Popped to existing")

            return true
        default:
            return await nextEventResponder?.handle(event: event) ?? false
        }
    }
}
