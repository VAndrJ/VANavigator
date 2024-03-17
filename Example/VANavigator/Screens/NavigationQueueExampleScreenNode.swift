//
//  NavigationQueueExampleScreenNode.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 23.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import VATextureKitRx

class NavigationQueueExampleScreenNode: ScreenNode<NavigationQueueExampleViewModel> {
    private lazy var titleTextNode = VATextNode(
        text: "Queue",
        fontStyle: .headline
    )
    private lazy var presentAndCloseButtonNode = VAButtonNode()
    private lazy var replaceRootButtonNode = VAButtonNode()
    private lazy var descriptionTextNode = TextNode(
        textObs: viewModel.descriptionObs,
        fontStyle: .body
    )

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        SafeArea {
            Column(spacing: 16, cross: .stretch) {
                titleTextNode
                    .padding(.bottom(32))
                presentAndCloseButtonNode
                replaceRootButtonNode
                descriptionTextNode
                    .padding(.top(16))
            }
            .padding(.all(16))
        }
    }

    override func viewDidLoad(in controller: UIViewController) {
        controller.title = "Queue"
    }

    override func configureTheme(_ theme: VATheme) {
        backgroundColor = theme.systemBackground
        presentAndCloseButtonNode.setTitle(#"Present and close "More" controller N times sequentially without delay"#, theme: theme)
        replaceRootButtonNode.setTitle("Replace root", theme: theme)
        setNeedsLayout()
    }

    override func bind() {
        bindView()
    }

    @MainActor
    private func bindView() {
        replaceRootButtonNode.onTap = viewModel ?> { $0.perform(ReplaceRootWithNewMainEvent()) }
        presentAndCloseButtonNode.onTap = viewModel ?> { $0.perform(PresentAndCloseEvent()) }
    }
}

struct PresentAndCloseEvent: Event {}

class NavigationQueueExampleViewModel: EventViewModel {
    struct Context {
        struct Navigation {
            let followReplaceRootWithNewMain: () -> Void
            let followPresentAndClose: (Int) -> Void
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
        case _ as ReplaceRootWithNewMainEvent:
            data.navigation.followReplaceRootWithNewMain()
        case _ as PresentAndCloseEvent:
            data.navigation.followPresentAndClose(5)
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
