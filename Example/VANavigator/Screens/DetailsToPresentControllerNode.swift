//
//  DetailsToPresentControllerNode.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import VATextureKitRx
import VANavigator

class DetailsToPresentControllerNode: DisplayNode<DetailsToPresentViewModel> {
    private let titleTextNode: VATextNode
    private let pushNextButtonNode = VAButtonNode().apply {
        $0.setTitle("Push next or pop to existing", with: nil, with: nil, for: .normal)
    }
    private let inputNode = TextFieldNode()
    private let detailsTextNode = VATextNode(
        text: "Single number for one screen, multiple numbers for multiple screens. Example: 1 or 1 2 3",
        fontStyle: .body
    )
    private let replaceRootButtonNode = VAButtonNode().apply {
        $0.setTitle("Replace root with new main", with: nil, with: nil, for: .normal)
    }
    private let descriptionTextNode = VATextNode(
        text: "",
        fontStyle: .body
    )

    override init(viewModel: DetailsToPresentViewModel) {
        self.titleTextNode = VATextNode(
            text: "Details \(viewModel.number)",
            fontStyle: .headline
        )

        super.init(viewModel: viewModel)

        bind()
    }

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        SafeArea {
            Column(spacing: 16, cross: .stretch) {
                titleTextNode
                pushNextButtonNode
                inputNode
                detailsTextNode
                replaceRootButtonNode
                    .padding(.top(32), .bottom(16))
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
    }

    private func bind() {
        bindView()
        bindViewModel()
    }

    private func bindView() {
        pushNextButtonNode.onTap = viewModel ?> { $0.perform(PushNextDetailsEvent()) }
        replaceRootButtonNode.onTap = viewModel ?> { $0.perform(ReplaceRootWithNewMainEvent()) }
        inputNode.child.rx.text
            .map {
                $0.flatMap {
                    $0.components(separatedBy: " ").compactMap { Int($0) }
                } ?? []
            }
            .bind(to: viewModel.nextNumberRelay)
            .disposed(by: bag)
    }

    private func bindViewModel() {
        viewModel.descriptionObs
            .subscribe(onNext: descriptionTextNode ?> { $0.text = $1 })
            .disposed(by: bag)
    }
}

struct PushNextDetailsEvent: Event {}

class DetailsToPresentViewModel: EventViewModel {
    struct DTO {
        struct Related {
            let value: Int
        }
        struct Navigation {
            let followReplaceRootWithNewMain: () -> Void
            let followPushOrPopNext: ([Int]) -> Void
        }

        let related: Related
        let navigation: Navigation
    }

    @Obs.Relay(value: "Normally opened")
    var descriptionObs: Observable<String>
    var nextNumberRelay = BehaviorRelay<[Int]>(value: [])
    var number: Int { data.related.value }

    private let data: DTO

    init(data: DTO) {
        self.data = data

        super.init()
    }

    override func run(_ event: Event) {
        switch event {
        case _ as ReplaceRootWithNewMainEvent:
            data.navigation.followReplaceRootWithNewMain()
        case _ as PushNextDetailsEvent:
            data.navigation.followPushOrPopNext(nextNumberRelay.value)
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
        default:
            return await nextEventResponder?.handle(event: event) ?? false
        }
    }
}

class TextFieldNode: VASizedViewWrapperNode<UITextField> {

    init() {
        super.init(
            childGetter: {
                let textField = UITextField()
                textField.borderStyle = .roundedRect
                return textField
            },
            sizing: .viewHeight
        )
    }
}