//
//  MainControllerNode.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import VATextureKitRx

class MainControllerNode: DisplayNode<MainViewModel> {
    private let titleTextNode: VATextNode
    private let replaceRootButtonNode = VAButtonNode()
    private let presentDetailsButtonNode = VAButtonNode()
    private let presentTabsButtonNode = VAButtonNode()
    private let descriptionTextNode = VATextNode(
        text: "",
        fontStyle: .body
    )

    override init(viewModel: MainViewModel) {
        self.titleTextNode = VATextNode(
            text: "Main \(Int.random(in: 0...100))",
            fontStyle: .headline
        )

        super.init(viewModel: viewModel)

        bind()
    }

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        SafeArea {
            Column(spacing: 16) {
                titleTextNode
                replaceRootButtonNode
                presentDetailsButtonNode
                presentTabsButtonNode
                descriptionTextNode
                    .padding(.top(16))
            }
            .padding(.all(16))
        }
    }

    override func configureTheme(_ theme: VATheme) {
        backgroundColor = theme.systemBackground
        replaceRootButtonNode.setTitle("Replace root with new main", theme: theme)
        presentDetailsButtonNode.setTitle("Present details", theme: theme)
        presentTabsButtonNode.setTitle("Present tabs", theme: theme)
    }

    private func bind() {
        bindView()
        bindViewModel()
    }

    private func bindView() {
        replaceRootButtonNode.onTap = viewModel ?> { $0.perform(ReplaceRootWithNewMainEvent()) }
        presentDetailsButtonNode.onTap = viewModel ?> { $0.perform(PushNextDetailsEvent()) }
        presentTabsButtonNode.onTap = viewModel ?> { $0.perform(PresentTabsEvent()) }
    }

    private func bindViewModel() {
        viewModel.descriptionObs
            .subscribe(onNext: descriptionTextNode ?> { $0.text = $1 })
            .disposed(by: bag)
    }
}

struct ReplaceRootWithNewMainEvent: Event {}

struct PresentTabsEvent: Event {}

class MainViewModel: EventViewModel {
    struct DTO {
        struct Navigation {
            let followReplaceRootWithNewMain: () -> Void
            let followPushOrPresentDetails: () -> Void
            let followTabs: () -> Void
        }

        let navigation: Navigation
    }

    @Obs.Relay(value: "Normally opened")
    var descriptionObs: Observable<String>

    private let data: DTO

    init(data: DTO) {
        self.data = data
    }

    override func run(_ event: Event) {
        switch event {
        case _ as ReplaceRootWithNewMainEvent:
            data.navigation.followReplaceRootWithNewMain()
        case _ as PushNextDetailsEvent:
            data.navigation.followPushOrPresentDetails()
        case _ as PresentTabsEvent:
            data.navigation.followTabs()
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
        case _ as ResponderReplacedWindowRootControllerEvent:
            _descriptionObs.rx.accept("Replaced root view controller")

            return true
        default:
            return await nextEventResponder?.handle(event: event) ?? false
        }
    }
}
