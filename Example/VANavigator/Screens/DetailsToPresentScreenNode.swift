//
//  DetailsToPresentScreenNode.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import VATextureKitRx

class DetailsToPresentScreenNode: ScreenNode<DetailsToPresentViewModel> {
    private let titleTextNode: VATextNode
    private lazy var pushNextButtonNode = ButtonNode(
        isEnabledObs: viewModel.isNavigationAvailableObs
    )
    private lazy var inputNode = TextFieldNode()
    private lazy var detailsTextNode = VATextNode(
        text: "Single number for one screen, multiple numbers for multiple screens. Example: 1 or 1 2 3",
        fontStyle: .body
    )
    private lazy var replaceRootButtonNode = VAButtonNode()
    private lazy var removeFromStackButtonNode = VAButtonNode()
    private lazy var descriptionTextNode = TextNode(
        textObs: viewModel.descriptionObs,
        fontStyle: .body
    )

    override init(viewModel: DetailsToPresentViewModel) {
        self.titleTextNode = VATextNode(
            text: "Details \(viewModel.number)",
            fontStyle: .headline
        )

        super.init(viewModel: viewModel)
    }

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        SafeArea {
            Column(spacing: 16, cross: .stretch) {
                titleTextNode
                pushNextButtonNode
                inputNode
                detailsTextNode
                replaceRootButtonNode
                    .padding(.top(32))
                removeFromStackButtonNode
                    .padding(.bottom(16))
                descriptionTextNode
            }
            .padding(.all(16))
        }
    }

    override func viewDidLoad(in controller: UIViewController) {
        controller.title = "\(viewModel.number)"
    }

    override func viewDidAppear(in controller: UIViewController, animated: Bool) {
        inputNode.child.becomeFirstResponder()
    }

    override func configureTheme(_ theme: VATheme) {
        backgroundColor = theme.systemBackground
        pushNextButtonNode.setTitle("Push next or pop to existing", theme: theme)
        replaceRootButtonNode.setTitle("Replace root with new main", theme: theme)
        removeFromStackButtonNode.setTitle("Remove -1 from navigation stack", theme: theme)
        setNeedsLayout()
    }

    override func bindView() {
        pushNextButtonNode.onTap = viewModel ?> { $0.perform(PushNextDetailsEvent()) }
        replaceRootButtonNode.onTap = viewModel ?> { $0.perform(ReplaceRootWithNewMainEvent()) }
        removeFromStackButtonNode.onTap = viewModel ?> { $0.perform(RemoveFromStackEvent()) }
        inputNode.child.rx.text
            .map {
                $0.flatMap {
                    $0.components(separatedBy: " ").compactMap { Int($0) }
                } ?? []
            }
            .bind(to: viewModel.nextNumberRelay)
            .disposed(by: bag)
    }
}

struct PushNextDetailsEvent: Event {}

struct RemoveFromStackEvent: Event {}

class DetailsToPresentViewModel: EventViewModel {
    struct Context {
        struct Related {
            let value: Int
        }
        struct Navigation {
            let followReplaceRootWithNewMain: () -> Void
            let followPushOrPopNext: ([Int]) -> Void
            let followRemoveFromStack: () -> Void
        }

        let related: Related
        let navigation: Navigation
    }

    var isNavigationAvailableObs: Observable<Bool> { nextNumberRelay.map(\.isNotEmpty) }
    @Obs.Relay(value: "Normally opened")
    var descriptionObs: Observable<String>
    var nextNumberRelay = BehaviorRelay<[Int]>(value: [])
    var number: Int { data.related.value }

    private let data: Context

    init(data: Context) {
        self.data = data

        super.init()
    }

    override func run(_ event: Event) {
        switch event {
        case _ as ReplaceRootWithNewMainEvent:
            data.navigation.followReplaceRootWithNewMain()
        case _ as PushNextDetailsEvent:
            data.navigation.followPushOrPopNext(nextNumberRelay.value)
        case _ as RemoveFromStackEvent:
            data.navigation.followRemoveFromStack()
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

class TextFieldNode: VASizedViewWrapperNode<UITextField> {

    convenience init() {
        self.init(
            actorChildGetter: { @MainActor in
                let textField = UITextField()
                textField.borderStyle = .roundedRect
                return textField
            },
            sizing: .viewHeight
        )
    }
}
