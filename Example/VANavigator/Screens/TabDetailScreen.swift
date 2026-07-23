//
//  TabDetailScreen.swift
//  VANavigator_Example
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Observation
import ObservationTracking
import Swiftional
import UIKit

final class TabDetailScreen: ControllerView<TabDetailViewModel> {
    private lazy var titleLabel = Label(
        text: "Tab Details",
        textStyle: .headline
    )
    private lazy var pushNextButton = Button(
        title: "Push next or pop to existing",
        onTap: viewModel ?> { $0.perform(PushNextDetailsEvent()) }
    )
    private lazy var numbersTextField = NumbersTextField(
        onEditingChanged: { [weak viewModel] numbers in
            viewModel?.perform(UpdateNextNumbers(nextNumbers: numbers))
        }
    )
    private lazy var detailsLabel = Label(
        text: "Single number for one screen, multiple numbers for multiple screens. Example: 1 or 1 2 3",
        textStyle: .body
    )
    private lazy var replaceRootButton = Button(
        title: "Replace root with new main",
        onTap: viewModel ?> { $0.perform(ReplaceRootWithNewMainEvent()) }
    )
    private lazy var descriptionLabel = Label(textStyle: .body)

    override func viewDidLoad(in controller: UIViewController) {
        controller.title = "Tab details"
    }

    override func viewDidAppear(in controller: UIViewController, animated: Bool) {
        numbersTextField.becomeFirstResponder()
    }

    override func addElements() {
        embedIntoScroll(
            titleLabel,
            pushNextButton,
            numbersTextField,
            Spacing(
                value: 32,
                child: detailsLabel
            ),
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
        pushNextButton.isEnabled = viewModel.nextNumbers.isNonEmpty
    }
}

private struct UpdateNextNumbers: Event {
    let nextNumbers: [Int]
}

@Observable
final class TabDetailViewModel: EventViewModel {
    struct Context {
        struct Navigation {
            let followReplaceRootWithNewMain: () -> Void
            let followPushOrPopNext: ([Int]) -> Void
        }

        let navigation: Navigation
    }

    private(set) var nextNumbers: [Int] = []

    private let context: Context

    init(context: Context) {
        self.context = context

        super.init()
    }

    override func run(_ event: any Event) {
        switch event {
        case let event as UpdateNextNumbers:
            nextNumbers = event.nextNumbers
        case _ as ReplaceRootWithNewMainEvent:
            context.navigation.followReplaceRootWithNewMain()
        case _ as PushNextDetailsEvent:
            context.navigation.followPushOrPopNext(nextNumbers)
        default:
            super.run(event)
        }
    }
}
