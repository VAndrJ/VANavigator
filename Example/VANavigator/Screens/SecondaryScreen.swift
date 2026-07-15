//
//  SecondaryScreen.swift
//  VANavigator_Example
//
//  Created by Volodymyr Andriienko on 04.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Observation
import ObservationTracking
import UIKit

final class SecondaryScreen: ControllerView<SecondaryViewModel> {
    private lazy var titleLabel = Label(
        text: "Secondary \(Int.random(in: 0...1000))",
        textStyle: .headline
    )
    private lazy var showSecondaryButton = Button(
        title: "Replace root with new main",
        onTap: viewModel ?> { $0.perform(ReplaceRootWithNewMainEvent()) }
    )
    private lazy var replaceRootButton = Button(
        title: "Show secondary",
        onTap: viewModel ?> { $0.perform(ShowSecondaryEvent()) }
    )
    private lazy var descriptionLabel = Label(textStyle: .body)

    override func viewDidLoad(in controller: UIViewController) {
        controller.title = "Secondary"
    }

    override func addElements() {
        embedIntoScroll(
            titleLabel,
            Spacing(value: 32, child: showSecondaryButton),
            Spacing(value: 16, child: replaceRootButton),
            descriptionLabel
        )
    }

    override func configure() {
        backgroundColor = .systemBackground
    }

    @ObservationTracking
    override func bindViewModel() {
        descriptionLabel.text = viewModel.openType
    }
}

@Observable
final class SecondaryViewModel: EventViewModel {
    struct Context {
        struct Navigation {
            let followReplaceRootWithNewMain: () -> Void
            let followShowSplitSecondary: () -> Void
        }

        let navigation: Navigation
    }

    private let context: Context

    init(context: Context) {
        self.context = context

        super.init()
    }

    override func run(_ event: any Event) {
        switch event {
        case _ as ShowSecondaryEvent:
            context.navigation.followShowSplitSecondary()
        case _ as ReplaceRootWithNewMainEvent:
            context.navigation.followReplaceRootWithNewMain()
        default:
            super.run(event)
        }
    }
}
