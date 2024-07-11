//
//  MainScreenNode.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import VATextureKitRx

class MainScreenNode: ScreenNode<MainViewModel> {
    private let titleTextNode: VATextNode
    private lazy var replaceRootButtonNode = VAButtonNode()
    private lazy var presentDetailsButtonNode = VAButtonNode()
    private lazy var presentTabsButtonNode = VAButtonNode()
    private lazy var presentQueueButtonNode = VAButtonNode()
    private lazy var presentSplitButtonNode = VAButtonNode()
    private lazy var showInSplitOrPresentButtonNode = VAButtonNode()
    private lazy var presentLoginedOnlyContentButtonNode = VAButtonNode()
    private lazy var descriptionTextNode = TextNode(
        textObs: viewModel.descriptionObs,
        fontStyle: .body
    )
    private lazy var authorizedTextNode = TextNode(
        textObs: viewModel.authorizationStatusObs,
        fontStyle: .body
    )

    override init(viewModel: MainViewModel) {
        self.titleTextNode = VATextNode(
            text: "Main \(Int.random(in: 0...100))",
            fontStyle: .headline
        )

        super.init(viewModel: viewModel)
    }

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        SafeArea {
            Column(spacing: 16) {
                titleTextNode
                replaceRootButtonNode
                presentDetailsButtonNode
                presentQueueButtonNode
                presentTabsButtonNode
                presentSplitButtonNode
                showInSplitOrPresentButtonNode
                descriptionTextNode
                    .padding(.top(16))
                presentLoginedOnlyContentButtonNode
                authorizedTextNode
            }
            .padding(.all(16))
        }
    }

    override func configureTheme(_ theme: VATheme) {
        backgroundColor = theme.systemBackground
        replaceRootButtonNode.setTitle("Replace root with new main", theme: theme)
        presentDetailsButtonNode.setTitle("Present details", theme: theme)
        presentTabsButtonNode.setTitle("Present tabs", theme: theme)
        presentSplitButtonNode.setTitle("Present split", theme: theme)
        showInSplitOrPresentButtonNode.setTitle("Show in split or present", theme: theme)
        presentLoginedOnlyContentButtonNode.setTitle("Present logined only content", theme: theme)
        presentQueueButtonNode.setTitle("Present queue example", theme: theme)
        setNeedsLayout()
    }

    override func bindView() {
        replaceRootButtonNode.onTap = viewModel ?> { $0.perform(ReplaceRootWithNewMainEvent()) }
        presentDetailsButtonNode.onTap = viewModel ?> { $0.perform(PushNextDetailsEvent()) }
        presentTabsButtonNode.onTap = viewModel ?> { $0.perform(PresentTabsEvent()) }
        presentSplitButtonNode.onTap = viewModel ?> { $0.perform(PresentSplitEvent()) }
        showInSplitOrPresentButtonNode.onTap = viewModel ?> { $0.perform(ShowInSplitOrPresentEvent()) }
        presentLoginedOnlyContentButtonNode.onTap = viewModel ?> { $0.perform(PresentLoginedOnlyEvent()) }
        presentQueueButtonNode.onTap = viewModel ?> { $0.perform(PresentQueueEvent()) }
    }
}

struct PresentLoginedOnlyEvent: Event {}

struct ReplaceRootWithNewMainEvent: Event {}

struct PresentTabsEvent: Event {}

struct PresentSplitEvent: Event {}

struct ShowInSplitOrPresentEvent: Event {}

struct PresentQueueEvent: Event {}

class MainViewModel: EventViewModel {
    struct Context {
        struct DataSource {
            let authorizedObs: Observable<Bool>
        }

        struct Navigation {
            let followReplaceRootWithNewMain: () -> Void
            let followPushOrPresentDetails: () -> Void
            let followTabs: () -> Void
            let followSplit: () -> Void
            let followShowInSplitOrPresent: () -> Void
            let followLoginedContent: () -> Void
            let followQueue: () -> Void
        }

        let source: DataSource
        let navigation: Navigation
    }

    var authorizationStatusObs: Observable<String> {
        data.source.authorizedObs
            .map { $0 ? "Authorized" : "Not authorized " }
    }
    @Obs.Relay(value: "Normally opened")
    var descriptionObs: Observable<String>

    private let data: Context

    init(data: Context) {
        self.data = data
    }

    override func run(_ event: any Event) {
        switch event {
        case _ as PresentQueueEvent:
            data.navigation.followQueue()
        case _ as PresentLoginedOnlyEvent:
            data.navigation.followLoginedContent()
        case _ as ShowInSplitOrPresentEvent:
            data.navigation.followShowInSplitOrPresent()
        case _ as ReplaceRootWithNewMainEvent:
            data.navigation.followReplaceRootWithNewMain()
        case _ as PushNextDetailsEvent:
            data.navigation.followPushOrPresentDetails()
        case _ as PresentTabsEvent:
            data.navigation.followTabs()
        case _ as PresentSplitEvent:
            data.navigation.followSplit()
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
        case _ as ResponderReplacedWindowRootControllerEvent:
            _descriptionObs.rx.accept("Replaced root view controller")

            return true
        default:
            return await nextEventResponder?.handle(event: event) ?? false
        }
    }
}
