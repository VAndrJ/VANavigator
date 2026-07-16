//
//  TabPresentExampleScreen.swift
//  VANavigator_Example
//
//  Created by Volodymyr Andriienko on 20.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Observation
import ObservationTracking
import Swiftional
import UIKit

final class TabPresentExampleScreen: ControllerView<TabPresentExampleViewModel> {
    private lazy var titleLabel = Label(
        text: "Tab Present Example",
        textStyle: .headline
    )
    private lazy var presentFromTopButton = Button(
        title: "Present from top controller",
        onTap: viewModel ?> { $0.perform(PresentFromTopEvent()) }
    )
    private lazy var presentFromTabButton = Button(
        title: "Present from tab bar controller",
        onTap: viewModel ?> { $0.perform(PresentFromTabEvent()) }
    )
    private lazy var presentPopoverButton = Button(
        title: "Present popover",
        onTap: viewModel ?> { $0.perform(PresentPopoverEvent(source: $1)) }
    )
    private lazy var descriptionLabel = Label(textStyle: .body)

    override func viewDidLoad(in controller: UIViewController) {
        controller.title = "Tab Present Example"
    }

    override func addElements() {
        embedIntoScroll(
            titleLabel,
            presentFromTopButton,
            presentFromTabButton,
            presentPopoverButton
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

struct PresentFromTopEvent: Event {}

struct PresentFromTabEvent: Event {}

struct PresentPopoverEvent: Event {
    let source: UIView
}

@Observable
final class TabPresentExampleViewModel: EventViewModel {
    struct Context {
        struct Navigation {
            let followPresentFromTop: () -> Void
            let followPresentFromTab: () -> Void
            let followPresentPopover: (UIView) -> Void
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
        case let event as PresentPopoverEvent:
            context.navigation.followPresentPopover(event.source)
        case _ as PresentFromTopEvent:
            context.navigation.followPresentFromTop()
        case _ as PresentFromTabEvent:
            context.navigation.followPresentFromTab()
        default:
            super.run(event)
        }
    }
}
