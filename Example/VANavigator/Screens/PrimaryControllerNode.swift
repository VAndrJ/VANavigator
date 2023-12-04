//
//  PrimaryControllerNode.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 04.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import VATextureKitRx

class PrimaryControllerNode: DisplayNode<PrimaryViewModel> {
    private let titleTextNode = VATextNode(
        text: "Primary",
        fontStyle: .headline
    )
    private let showSecondaryButtonNode = VAButtonNode()
    private let replaceRootButtonNode = VAButtonNode()
    private let showInSplitOrPresentButtonNode = VAButtonNode()
    private let descriptionTextNode = VATextNode(
        text: "",
        fontStyle: .body
    )

    override init(viewModel: PrimaryViewModel) {
        super.init(viewModel: viewModel)

        bind()
    }

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        SafeArea {
            Column(spacing: 16, cross: .stretch) {
                titleTextNode
                showSecondaryButtonNode
                showInSplitOrPresentButtonNode
                replaceRootButtonNode
                    .padding(.top(32), .bottom(16))
                descriptionTextNode
            }
            .padding(.all(16))
        }
    }

    override func viewDidLoad(in controller: UIViewController) {
        controller.title = "Primary"
    }

    override func configureTheme(_ theme: VATheme) {
        backgroundColor = theme.systemBackground
        replaceRootButtonNode.setTitle("Replace root with new main", theme: theme)
        showSecondaryButtonNode.setTitle("Show secondary", theme: theme)
        showInSplitOrPresentButtonNode.setTitle("Show in split or present", theme: theme)
    }

    private func bind() {
        bindView()
        bindViewModel()
    }

    private func bindView() {
        replaceRootButtonNode.onTap = viewModel ?> { $0.perform(ReplaceRootWithNewMainEvent()) }
        showSecondaryButtonNode.onTap = viewModel ?> { $0.perform(ShowSecondaryEvent()) }
        showInSplitOrPresentButtonNode.onTap = viewModel ?> { $0.perform(ShowInSplitOrPresentEvent()) }
    }

    private func bindViewModel() {
        viewModel.descriptionObs
            .bind(to: descriptionTextNode.rx.text)
            .disposed(by: bag)
    }
}

struct ShowSecondaryEvent: Event {}

class PrimaryViewModel: EventViewModel {
    struct DTO {
        struct Navigation {
            let followReplaceRootWithNewMain: () -> Void
            let followShowSplitSecondary: () -> Void
            let followShowInSplitOrPresent: () -> Void
        }

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
        case _ as ShowSecondaryEvent:
            data.navigation.followShowSplitSecondary()
        case _ as ReplaceRootWithNewMainEvent:
            data.navigation.followReplaceRootWithNewMain()
        case _ as ShowInSplitOrPresentEvent:
            data.navigation.followShowInSplitOrPresent()
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
