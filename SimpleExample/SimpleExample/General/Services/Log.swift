//
//  Log.swift
//  SimpleExample
//
//  Created by VAndrJ on 13.02.2024.
//

import Foundation
import os

extension OSLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.vandrj"

    @MainActor
    static let responderChain = OSLog(subsystem: subsystem, category: "ResponderChain")
}

@MainActor
func logResponder(from: Any, event: ResponderEvent) {
    #if DEBUG || targetEnvironment(simulator)
    os_log("[ %{public}@ ]: %{public}@", log: OSLog.responderChain, type: .info, String(describing: from), String(describing: event))
    #endif
}
