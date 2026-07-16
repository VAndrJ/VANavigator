//
//  NavigationQueueExampleScreen.swift
//  VANavigator_Example
//
//  Created by Volodymyr Andriienko on 23.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Observation
import ObservationTracking
import Swiftional
import UIKit

final class NavigationQueueExampleScreen: ControllerView<NavigationQueueExampleViewModel> {
    private lazy var titleLabel = Label(
        text: "Queue",
        textStyle: .headline
    )
    private lazy var presentAndCloseButton = Button(
        title: #"Present and close "More" controller few times sequentially without delay"#,
        onTap: viewModel ?> { $0.perform(PresentAndCloseEvent()) }
    )
    private lazy var replaceRootButton = Button(
        title: "Replace root",
        onTap: viewModel ?> { $0.perform(ReplaceRootWithNewMainEvent()) }
    )
    private lazy var descriptionLabel = Label(textStyle: .body)

    override func viewDidLoad(in controller: UIViewController) {
        controller.title = "Queue"
    }

    override func addElements() {
        embedIntoScroll(
            Spacing(
                value: 32,
                child: titleLabel
            ),
            presentAndCloseButton,
            Spacing(
                value: 16,
                child: replaceRootButton
            ),
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

struct PresentAndCloseEvent: Event {}

@Observable
final class NavigationQueueExampleViewModel: EventViewModel {
    struct Context {
        struct Navigation {
            let followReplaceRootWithNewMain: () -> Void
            let followPresentAndClose: (Int) -> Void
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
        case _ as PresentAndCloseEvent:
            context.navigation.followPresentAndClose(5)
        default:
            super.run(event)
        }
    }
}
