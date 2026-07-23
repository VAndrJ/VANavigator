//
//  ShortcutService.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

final class ShortcutsService {
    func addShortcuts() {
        UIApplication.shared.shortcutItems = [
            .init(type: .main),
            .init(type: .details),
            .init(type: .alert),
        ]
    }
}

extension UIApplicationShortcutItem {
    fileprivate convenience init(type source: Shortcut) {
        self.init(
            type: source.rawValue,
            localizedTitle: source.title,
            localizedSubtitle: source.subtitle,
            icon: source.icon,
            userInfo: nil
        )
    }
}

enum Shortcut: String {
    case main = "com.vandrj.VANavigator.main"
    case details = "com.vandrj.VANavigator.details"
    case alert = "com.vandrj.VANavigator.alert"

    var title: String {
        switch self {
        case .main: "Main"
        case .details: "Details"
        case .alert: "Alert"
        }
    }
    var subtitle: String? {
        switch self {
        case .main: "Replace root with new main"
        case .details: "Push or pop to existing"
        case .alert: "Display alert"
        }
    }
    var icon: UIApplicationShortcutIcon {
        switch self {
        case .main: .init(type: .home)
        case .details: .init(type: .task)
        case .alert: .init(type: .alarm)
        }
    }
}

@MainActor
struct ResponderOpenedFromShortcutEvent: ResponderEvent {}
