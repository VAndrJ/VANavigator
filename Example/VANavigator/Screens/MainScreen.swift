//
//  MainScreen.swift
//  VANavigator_Example
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Observation
import ObservationTracking
import Swiftional
import UIKit

final class MainScreen: ControllerView<MainViewModel> {
    private lazy var titleLabel = Label(
        text: "Main \(Int.random(in: 0...100))",
        textStyle: .headline
    )
    private lazy var replaceRootButton = Button(
        title: "Replace root with new main",
        onTap: viewModel ?> { $0.perform(ReplaceRootWithNewMainEvent()) }
    )
    private lazy var presentDetailsButton = Button(
        title: "Open details (pop or present)",
        onTap: viewModel ?> { $0.perform(PushNextDetailsEvent()) }
    )
    private lazy var presentTabsButton = Button(
        title: "Open tabs (close or replace root)",
        onTap: viewModel ?> { $0.perform(PresentTabsEvent()) }
    )
    private lazy var presentQueueButton = Button(
        title: "Present queue example",
        onTap: viewModel ?> { $0.perform(PresentQueueEvent()) }
    )
    private lazy var presentSplitButton = Button(
        title: "Open split (close or present)",
        onTap: viewModel ?> { $0.perform(PresentSplitEvent()) }
    )
    private lazy var showInSplitOrPresentButton = Button(
        title: "Show in split or present",
        onTap: viewModel ?> { $0.perform(ShowInSplitOrPresentEvent()) }
    )
    private lazy var presentAuthorizedOnlyContentButton = Button(
        title: "Open authorization-protected content",
        onTap: viewModel ?> { $0.perform(PresentAuthorizedOnlyEvent()) }
    )
    private lazy var descriptionLabel = Label(textStyle: .body)
    private lazy var authorizedLabel = Label(textStyle: .body)

    override func addElements() {
        embedIntoScroll(
            titleLabel,
            replaceRootButton,
            presentDetailsButton,
            presentQueueButton,
            presentTabsButton,
            presentSplitButton,
            Spacing(
                value: 16,
                child: showInSplitOrPresentButton
            ),
            descriptionLabel,
            presentAuthorizedOnlyContentButton,
            authorizedLabel,
        )
    }

    override func configure() {
        backgroundColor = .systemBackground
    }

    @ObservationTracking
    override func bindViewModel() {
        descriptionLabel.text = viewModel.openType
        authorizedLabel.text = viewModel.authorizationStatus
    }
}

struct PresentAuthorizedOnlyEvent: Event {}

struct ReplaceRootWithNewMainEvent: Event {}

struct PushNextDetailsEvent: Event {}

struct PresentTabsEvent: Event {}

struct PresentSplitEvent: Event {}

struct ShowInSplitOrPresentEvent: Event {}

struct PresentQueueEvent: Event {}

@Observable
final class MainViewModel: EventViewModel {
    struct Context {
        struct DataSource {
            let authorizationService: AuthorizationService
        }

        struct Navigation {
            let followReplaceRootWithNewMain: () -> Void
            let followPushOrPresentDetails: () -> Void
            let followTabs: () -> Void
            let followSplit: () -> Void
            let followShowInSplitOrPresent: () -> Void
            let followAuthorizedContent: () -> Void
            let followQueue: () -> Void
        }

        let source: DataSource
        let navigation: Navigation
    }

    var authorizationStatus: String {
        context.source.authorizationService.isAuthorized ? "Authorized" : "Not authorized"
    }

    private let context: Context

    init(context: Context) {
        self.context = context
    }

    override func run(_ event: any Event) {
        switch event {
        case _ as PresentQueueEvent:
            context.navigation.followQueue()
        case _ as PresentAuthorizedOnlyEvent:
            context.navigation.followAuthorizedContent()
        case _ as ShowInSplitOrPresentEvent:
            context.navigation.followShowInSplitOrPresent()
        case _ as ReplaceRootWithNewMainEvent:
            context.navigation.followReplaceRootWithNewMain()
        case _ as PushNextDetailsEvent:
            context.navigation.followPushOrPresentDetails()
        case _ as PresentTabsEvent:
            context.navigation.followTabs()
        case _ as PresentSplitEvent:
            context.navigation.followSplit()
        default:
            super.run(event)
        }
    }
}
