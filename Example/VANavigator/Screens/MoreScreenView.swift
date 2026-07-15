//
//  MoreScreenView.swift
//  VANavigator_Example
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Observation
import ObservationTracking
import UIKit

final class MoreScreenView: ControllerView<MoreViewModel> {
    private lazy var titleLabel = Label(
        text: "More",
        textStyle: .headline
    )
    private lazy var replaceRootButtonNode = Button(title: "Replace root with new main")
    private lazy var descriptionLabel = Label(
        textStyle: .body
    )

    override func addElements() {
        embedIntoScroll(
            titleLabel,
            replaceRootButtonNode,
            descriptionLabel,
        )
    }

    override func viewDidLoad(in controller: UIViewController) {
        controller.title = "More"
    }

    override func configure() {
        backgroundColor = .systemBackground
    }

    override func bindView() {
        replaceRootButtonNode.onTap = viewModel ?> { $0.perform(ReplaceRootWithNewMainEvent()) }
    }

    @ObservationTracking
    override func bindViewModel() {
        descriptionLabel.text = viewModel.openType
    }
}

@Observable
final class MoreViewModel: EventViewModel {
    struct Context {
        struct Navigation {
            let followReplaceRootWithNewMain: () -> Void
        }

        let navigation: Navigation
    }

    private(set) var openType = ""

    private let data: Context

    init(data: Context) {
        self.data = data

        super.init()
    }

    override func run(_ event: any Event) {
        switch event {
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
            openType = "Opened from shortcut"

            return true
        case _ as ResponderPoppedToExistingEvent:
            openType = "Popped to existing"

            return true
        default:
            return await nextEventResponder?.handle(event: event) ?? false
        }
    }
}
