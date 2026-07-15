//
//  EventViewModel.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Observation
import UIKit

struct BecomeVisibleEvent: Event {}

protocol Event {}

@Observable
class EventViewModel: ViewModel {
    weak var controller: UIViewController?

    private(set) var openType = ""

    func run(_ event: any Event) {
        #if DEBUG || targetEnvironment(simulator)
        debugPrint("⚠️ [Event not handled] \(event)")
        #endif
    }

    func perform(_ event: any Event) {
        run(event)
    }

    // MARK: - Responder

    override func handle(event: any ResponderEvent) async -> Bool {
        logResponder(from: self, event: event)
        switch event {
        case _ as ResponderOpenedFromShortcutEvent:
            openType = "Opened from shortcut"

            return true
        case _ as ResponderPoppedToExistingEvent:
            openType = "Popped to existing"

            return true
        default:
            return await nextEventResponder?.handle(event: event) ?? false
        }
    }
}

class ViewModel: NSObject, Responder {

    // MARK: - Responder

    weak var nextEventResponder: (any Responder)?

    func handle(event: any ResponderEvent) async -> Bool {
        logResponder(from: Self.self, event: event)

        return await nextEventResponder?.handle(event: event) ?? false
    }
}
