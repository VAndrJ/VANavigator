//
//  MainScreenView.swift
//  SimpleExample
//
//  Created by VAndrJ on 13.02.2024.
//

import UIKit

class MainScreenView: ControllerView<MainViewModel> {
    private let titleLabel = UILabel().apply {
        $0.text = "Main \(Int.random(in: 0...100))"
    }
    private let pushOrPresentDetailsButton = Button(title: "Push or present details")
    private let replaceRootButton = Button(title: "Replace window root")

    override func addElements() {
        embedIntoScroll(
            titleLabel,
            pushOrPresentDetailsButton,
            replaceRootButton
        )
    }

    override func configure() {
        backgroundColor = .systemBackground
    }

    override func bindView() {
        replaceRootButton.onTap = viewModel ?> { $0.perform(ReplaceRootWithNewMainEvent()) }
        pushOrPresentDetailsButton.onTap = viewModel ?> { $0.perform(PushOrPresentDetailsEvent()) }
    }
}

struct ReplaceRootWithNewMainEvent: Event {}

struct PushOrPresentDetailsEvent: Event {}

class MainViewModel: EventViewModel {
    struct Context {
        struct DataSource {
        }

        struct Navigation {
            let followReplaceRootWithNewMain: () -> Void
            let followPushOrPresentDetails: () -> Void
        }

        let source: DataSource
        let navigation: Navigation
    }

    private let data: Context

    init(data: Context) {
        self.data = data
    }

    override func run(_ event: Event) async {
        switch event {
        case _ as ReplaceRootWithNewMainEvent:
            data.navigation.followReplaceRootWithNewMain()
        case _ as PushOrPresentDetailsEvent:
            data.navigation.followPushOrPresentDetails()
        default:
            await super.run(event)
        }
    }

    override func handle(event: ResponderEvent) async -> Bool {
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
