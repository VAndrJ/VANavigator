//
//  TabPresentExampleScreenNode.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 20.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import VATextureKitRx

class TabPresentExampleScreenNode: ScreenNode<TabPresentExampleViewModel> {
    private lazy var titleTextNode = VATextNode(
        text: "Tab Present Example",
        fontStyle: .headline
    )
    private lazy var presentFromTopButtonNode = VAButtonNode()
    private lazy var presentFromTabButtonNode = VAButtonNode()
    private lazy var presentPopoverButtonNode = VAButtonNode()

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        SafeArea {
            Column(spacing: 16, cross: .stretch) {
                presentFromTopButtonNode
                presentFromTabButtonNode
                presentPopoverButtonNode
            }
            .padding(.all(16))
        }
    }

    override func viewDidLoad(in controller: UIViewController) {
        controller.title = "Tab Present Example"
    }

    override func configureTheme(_ theme: VATheme) {
        backgroundColor = theme.systemBackground
        presentFromTopButtonNode.setTitle("Present from top controller", theme: theme)
        presentFromTabButtonNode.setTitle("Present from tab bar controller", theme: theme)
        presentPopoverButtonNode.setTitle("Present popover", theme: theme)
        setNeedsLayout()
    }

    override func bind() {
        bindView()
    }

    @MainActor
    private func bindView() {
        presentFromTopButtonNode.onTap = viewModel ?> { $0.perform(PresentFromTopEvent()) }
        presentFromTabButtonNode.onTap = viewModel ?> { $0.perform(PresentFromTabEvent()) }
        presentPopoverButtonNode.onTap = viewModel ?> { [weak self] in
            guard let self else { return }

            $0.perform(PresentPopoverEvent(source: self.presentPopoverButtonNode.view))
        }
    }
}

struct PresentFromTopEvent: Event {}

struct PresentFromTabEvent: Event {}

struct PresentPopoverEvent: Event {
    let source: UIView
}

class TabPresentExampleViewModel: EventViewModel {
    struct Context {
        struct Navigation {
            let followPresentFromTop: () -> Void
            let followPresentFromTab: () -> Void
            let followPresentPopover: (UIView) -> Void
        }

        let navigation: Navigation
    }

    var isNavigationAvailableObs: Observable<Bool> { nextNumberRelay.map(\.isNotEmpty) }
    @Obs.Relay(value: "Normally opened")
    var descriptionObs: Observable<String>
    var nextNumberRelay = BehaviorRelay<[Int]>(value: [])

    private let data: Context

    init(data: Context) {
        self.data = data

        super.init()
    }

    override func run(_ event: Event) {
        switch event {
        case let event as PresentPopoverEvent:
            data.navigation.followPresentPopover(event.source)
        case _ as PresentFromTopEvent:
            data.navigation.followPresentFromTop()
        case _ as PresentFromTabEvent:
            data.navigation.followPresentFromTab()
        default:
            super.run(event)
        }
    }

    override func handle(event: ResponderEvent) async -> Bool {
        logResponder(from: self, event: event)
        switch event {
        case _ as ResponderOpenedFromShortcutEvent:
            _descriptionObs.rx.accept("Opened from shortcut")

            return true
        case _ as ResponderPoppedToExistingEvent:
            _descriptionObs.rx.accept("Popped to existing")

            return true
        default:
            return await nextEventResponder?.handle(event: event) ?? false
        }
    }
}
