//
//  DetailsScreenView.swift
//  SimpleExample
//
//  Created by VAndrJ on 13.02.2024.
//

import UIKit

class DetailsScreenView: ControllerView<DetailsViewModel> {
    private lazy var titleLabel = UILabel().apply {
        $0.text = "Details \(viewModel.number)"
    }
    private let closeIfTopPushedOrPresentedButton = Button(title: "Close if top pushed or presented")
    private let replaceRootButton = Button(title: "Replace window root")

    override func addElements() {
        embedIntoScroll(
            titleLabel,
            closeIfTopPushedOrPresentedButton,
            replaceRootButton
        )
    }

    override func configure() {
        backgroundColor = .systemBackground
    }

    override func bindView() {
        replaceRootButton.onTap = viewModel ?> { $0.perform(ReplaceRootWithNewMainEvent()) }
        closeIfTopPushedOrPresentedButton.onTap = viewModel ?> { $0.perform(CloseIfTopPushedOrPresentedEvent()) }
    }
}

struct CloseIfTopPushedOrPresentedEvent: Event {}

class DetailsViewModel: EventViewModel {
    struct Context {
        struct Related {
            let number: Int
        }

        struct DataSource {
        }

        struct Navigation {
            let followReplaceRootWithNewMain: () -> Void
            let followCloseIfTopPushedOrPresented: () -> Void
        }

        let related: Related
        let source: DataSource
        let navigation: Navigation
    }

    var number: Int { data.related.number }

    private let data: Context

    init(data: Context) {
        self.data = data
    }

    override func run(_ event: Event) async {
        switch event {
        case _ as ReplaceRootWithNewMainEvent:
            data.navigation.followReplaceRootWithNewMain()
        case _ as CloseIfTopPushedOrPresentedEvent:
            data.navigation.followCloseIfTopPushedOrPresented()
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
