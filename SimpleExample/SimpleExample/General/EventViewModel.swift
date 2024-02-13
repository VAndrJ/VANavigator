//
//  EventViewModel.swift
//  SimpleExample
//
//  Created by VAndrJ on 13.02.2024.
//

import UIKit

struct BecomeVisibleEvent: Event {}

protocol Event {}

class EventViewModel: ViewModel {
    weak var controller: UIViewController?

    @MainActor
    func run(_ event: Event) async {
        #if DEBUG || targetEnvironment(simulator)
        print("⚠️ [Event not handled] \(event)")
        #endif
    }

    func perform(_ event: Event) {
        Task { @MainActor in
            await run(event)
        }
    }
}

class ViewModel: NSObject, Responder {

    // MARK: - Responder

    weak var nextEventResponder: Responder?

    func handle(event: ResponderEvent) async -> Bool {
        logResponder(from: Self.self, event: event)

        return await nextEventResponder?.handle(event: event) ?? false
    }
}
