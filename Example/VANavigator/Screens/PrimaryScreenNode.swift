//
//  PrimaryScreenNode.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 04.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import VATextureKitRx

class PrimaryScreenNode: ScreenNode<PrimaryViewModel> {
    private lazy var titleTextNode = VATextNode(
        text: "Primary \(Int.random(in: 0...100))",
        fontStyle: .headline
    )
    private lazy var replacePrimartButtonNode = VAButtonNode()
    private lazy var showSecondaryButtonNode = VAButtonNode()
    private lazy var replaceRootButtonNode = VAButtonNode()
    private lazy var showInSplitOrPresentButtonNode = VAButtonNode()
    private lazy var descriptionTextNode = TextNode(
        textObs: viewModel.descriptionObs,
        fontStyle: .body
    )

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        SafeArea {
            Column(spacing: 16, cross: .stretch) {
                titleTextNode
                replacePrimartButtonNode
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
        replacePrimartButtonNode.setTitle("Replace primary", theme: theme)
        setNeedsLayout()
    }

    override func bind() {
        bindView()
    }

    @MainActor
    private func bindView() {
        replaceRootButtonNode.onTap = viewModel ?> { $0.perform(ReplaceRootWithNewMainEvent()) }
        showSecondaryButtonNode.onTap = viewModel ?> { $0.perform(ShowSecondaryEvent()) }
        showInSplitOrPresentButtonNode.onTap = viewModel ?> { $0.perform(ShowInSplitOrPresentEvent()) }
        replacePrimartButtonNode.onTap = viewModel ?> { $0.perform(ReplacePrimaryEvent()) }
    }
}

struct ShowSecondaryEvent: Event {}

struct ReplacePrimaryEvent: Event {}

class PrimaryViewModel: EventViewModel {
    struct Context {
        struct Navigation {
            let followReplaceRootWithNewMain: () -> Void
            let followReplacePrimary: () -> Void
            let followShowSplitSecondary: () -> Void
            let followShowInSplitOrPresent: () -> Void
        }

        let navigation: Navigation
    }

    @Obs.Relay(value: "Normally opened")
    var descriptionObs: Observable<String>

    private let data: Context

    init(data: Context) {
        self.data = data

        super.init()
    }

    override func run(_ event: Event) {
        switch event {
        case _ as ReplacePrimaryEvent:
            data.navigation.followReplacePrimary()
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
