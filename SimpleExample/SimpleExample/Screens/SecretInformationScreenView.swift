//
//  SecretInformationScreenView.swift
//  SimpleExample
//
//  Created by VAndrJ on 13.02.2024.
//

import UIKit

class SecretInformationScreenView: ControllerView<SecretInformationViewModel> {
    private lazy var titleLabel = UILabel().apply {
        $0.text = "Secret information for authorized users only"
    }
    private let replaceRootButton = Button(title: "Replace window root")

    override func addElements() {
        embedIntoScroll(
            titleLabel,
            replaceRootButton
        )
    }

    override func configure() {
        backgroundColor = .systemBackground
    }

    override func bindView() {
        replaceRootButton.onTap = viewModel ?> { $0.perform(ReplaceRootWithNewMainEvent()) }
    }
}

class SecretInformationViewModel: EventViewModel {
    struct Context {
        struct Related {
        }

        struct DataSource {
        }

        struct Navigation {
            let followReplaceRootWithNewMain: () -> Void
        }

        let related: Related
        let source: DataSource
        let navigation: Navigation
    }

    private let data: Context

    init(data: Context) {
        self.data = data
    }

    override func run(_ event: any Event) async {
        switch event {
        case _ as ReplaceRootWithNewMainEvent:
            data.navigation.followReplaceRootWithNewMain()
        default:
            await super.run(event)
        }
    }

    override func handle(event: any ResponderEvent) async -> Bool {
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
