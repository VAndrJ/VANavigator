//
//  ShortcutService.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit

@MainActor
final class ShortcutsService {

    func addShortcuts() {
        UIApplication.shared.shortcutItems?.removeAll()
        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(type: .main),
            UIApplicationShortcutItem(type: .details),
            UIApplicationShortcutItem(type: .alert),
        ]
    }
}

private extension UIApplicationShortcutItem {

    convenience init(type source: Shortcut) {
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
        case .main: return "Main"
        case .details: return "Details"
        case .alert: return "Alert"
        }
    }
    var subtitle: String? {
        switch self {
        case .main: return "Replace root with new main"
        case .details: return "Push or pop to existing"
        case .alert: return "Display alert"
        }
    }
    var icon: UIApplicationShortcutIcon {
        switch self {
        case .main: return UIApplicationShortcutIcon(type: .home)
        case .details: return UIApplicationShortcutIcon(type: .task)
        case .alert: return UIApplicationShortcutIcon(type: .alarm)
        }
    }
}

struct ResponderOpenedFromShortcutEvent: ResponderEvent {}
