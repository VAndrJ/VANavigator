//
//  Log.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Foundation
import os
import VANavigator

extension OSLog {
    private static var subsystem = Bundle.main.bundleIdentifier!

    static let responderChain = OSLog(subsystem: subsystem, category: "ResponderChain")
}

func logResponder(from: Any, event: ResponderEvent) {
    #if DEBUG || targetEnvironment(simulator)
    os_log("%{public}@ %{public}@", log: OSLog.responderChain, type: .info, String(describing: from), String(describing: event))
    #endif
}