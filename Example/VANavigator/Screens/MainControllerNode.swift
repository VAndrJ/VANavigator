//
//  MainControllerNode.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import VATextureKit

class MainControllerNode: DisplayNode<MainViewModel> {
    private let titleTextNode: VATextNode
    private let replaceRootButtonNode = VAButtonNode().apply {
        $0.setTitle("Replace root with new main", with: nil, with: nil, for: .normal)
    }
    private let presentDetailsButtonNode = VAButtonNode().apply {
        $0.setTitle("Present details", with: nil, with: nil, for: .normal)
    }

    override init(viewModel: MainViewModel) {
        self.titleTextNode = VATextNode(
            text: "Main \(Int.random(in: 0...100))",
            fontStyle: .headline
        )

        super.init(viewModel: viewModel)

        bind()
    }

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        SafeArea {
            Column(spacing: 16) {
                titleTextNode
                replaceRootButtonNode
                presentDetailsButtonNode
            }
            .padding(.all(16))
        }
    }

    override func configureTheme(_ theme: VATheme) {
        backgroundColor = theme.systemBackground
    }

    private func bind() {
        replaceRootButtonNode.onTap = viewModel ?> { $0.perform(ReplaceRootWithNewMainEvent()) }
        presentDetailsButtonNode.onTap = viewModel ?> { $0.perform(PushNextDetailsEvent()) }
    }
}

struct ReplaceRootWithNewMainEvent: Event {}

class MainViewModel: EventViewModel {
    struct DTO {
        struct Navigation {
            let followReplaceRootWithNewMain: () -> Void
            let pushOrPresentDetails: () -> Void
        }

        let navigation: Navigation
    }

    private let data: DTO

    init(data: DTO) {
        self.data = data
    }

    override func run(_ event: Event) {
        switch event {
        case _ as ReplaceRootWithNewMainEvent:
            data.navigation.followReplaceRootWithNewMain()
        case _ as PushNextDetailsEvent:
            data.navigation.pushOrPresentDetails()
        default:
            super.run(event)
        }
    }
}
