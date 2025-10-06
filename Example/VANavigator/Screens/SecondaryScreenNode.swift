//
//  SecondaryScreenNode.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 04.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import RxSwift
import VATextureKitRx

class SecondaryScreenNode: ScreenNode<SecondaryViewModel>, @unchecked Sendable {
    private lazy var titleTextNode = VATextNode(
        text: "Secondary \(Int.random(in: 0...1000))",
        fontStyle: .headline
    )
    private lazy var showSecondaryButtonNode = VAButtonNode()
    private lazy var replaceRootButtonNode = VAButtonNode()
    private lazy var descriptionTextNode = TextNode(
        textObs: viewModel.descriptionObs,
        fontStyle: .body
    )

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        SafeArea {
            Column(spacing: 16, cross: .stretch) {
                titleTextNode
                showSecondaryButtonNode
                replaceRootButtonNode
                    .padding(.top(32), .bottom(16))
                descriptionTextNode
            }
            .padding(.all(16))
        }
    }

    override func viewDidLoad(in controller: UIViewController) {
        controller.title = "Secondary"
    }

    override func configureTheme(_ theme: VATheme) {
        backgroundColor = theme.systemBackground
        replaceRootButtonNode.setTitle("Replace root with new main", theme: theme)
        showSecondaryButtonNode.setTitle("Show secondary", theme: theme)
        setNeedsLayout()
    }

    override func bindView() {
        replaceRootButtonNode.onTap = viewModel ?> { $0.perform(ReplaceRootWithNewMainEvent()) }
        showSecondaryButtonNode.onTap = viewModel ?> { $0.perform(ShowSecondaryEvent()) }
    }
}

class SecondaryViewModel: EventViewModel {
    struct Context {
        struct Navigation {
            let followReplaceRootWithNewMain: () -> Void
            let followShowSplitSecondary: () -> Void
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

    override func run(_ event: any Event) {
        switch event {
        case _ as ShowSecondaryEvent:
            data.navigation.followShowSplitSecondary()
        case _ as ReplaceRootWithNewMainEvent:
            data.navigation.followReplaceRootWithNewMain()
        default:
            super.run(event)
        }
    }

    override func handle(event: any ResponderEvent) async -> Bool {
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
