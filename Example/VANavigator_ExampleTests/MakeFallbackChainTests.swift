//
//  MakeFallbackChainTests.swift
//  VANavigator_ExampleTests
//
//  Created by VAndrJ on 20.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Testing
import UIKit
import VANavigator

// TODO: - Messages
@Suite(.serialized)
final class MakeFallbackChainTests {
    @Test
    func `Builds fallback chain in strategy order`() async {
        let destination = NavigationDestination.identity(MockRootControllerNavigationIdentity())
        let strategy = NavigationStrategy.push()
        let animated = true
        var expected: NavigationChainLink? = NavigationChainLink(
            destination: destination,
            strategy: strategy,
            animated: animated,
            fallback: NavigationChainLink(
                destination: destination,
                strategy: .replaceNavigationRoot,
                animated: animated,
                fallback: NavigationChainLink(
                    destination: destination,
                    strategy: .present(),
                    animated: animated,
                    fallback: NavigationChainLink(
                        destination: destination,
                        strategy: .replaceWindowRoot(),
                        animated: animated,
                        fallback: NavigationChainLink(
                            destination: destination,
                            strategy: .popToExisting(),
                            animated: animated,
                            fallback: NavigationChainLink(
                                destination: destination,
                                strategy: .closeIfTop(),
                                animated: animated,
                                fallback: nil
                            )
                        )
                    )
                )
            )
        )
        var sut: NavigationChainLink? = Navigator(window: nil, screenFactory: MockScreenFactory()).makeFallbackChain(
            destination: destination,
            animated: animated,
            fallbackStrategies: [
                strategy,
                .replaceNavigationRoot,
                .present(),
                .replaceWindowRoot(),
                .popToExisting(),
                .closeIfTop(),
            ]
        )
        while !(expected == nil && sut == nil) {
            #expect((true) == (expected?.isEqual(to: sut)))
            expected = expected?.fallback
            sut = sut?.fallback
        }
    }
}
