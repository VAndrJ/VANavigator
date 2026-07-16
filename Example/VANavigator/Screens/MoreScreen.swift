//
//  MoreScreen.swift
//  VANavigator_Example
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Observation
import ObservationTracking
import Swiftional
import UIKit

final class MoreScreen: ControllerView<MoreViewModel> {
    private lazy var titleLabel = Label(
        text: "More",
        textStyle: .headline
    )
    private lazy var replaceRootButtonNode = Button(
        title: "Replace root with new main",
        onTap: viewModel ?> { $0.perform(ReplaceRootWithNewMainEvent()) }
    )
    private lazy var descriptionLabel = Label(textStyle: .body)

    override func viewDidLoad(in controller: UIViewController) {
        controller.title = "More"
    }

    override func addElements() {
        embedIntoScroll(
            titleLabel,
            Spacing(
                value: 32,
                child: replaceRootButtonNode
            ),
            descriptionLabel,
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
final class MoreViewModel: EventViewModel {
    struct Context {
        struct Navigation {
            let followReplaceRootWithNewMain: () -> Void
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
        case _ as ReplaceRootWithNewMainEvent:
            context.navigation.followReplaceRootWithNewMain()
        default:
            super.run(event)
        }
    }
}
