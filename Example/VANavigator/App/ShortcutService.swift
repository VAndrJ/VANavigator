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
        UIApplication.shared.shortcutItems?.removeAll()
        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(type: .main),
            UIApplicationShortcutItem(type: .details),
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

    var title: String {
        switch self {
        case .main: return "Main"
        case .details: return "Details"
        }
    }
    var subtitle: String? {
        switch self {
        case .main: return "Replace root with new main"
        case .details: return "Push or pop to existing"
        }
    }
    var icon: UIApplicationShortcutIcon {
        switch self {
        case .main: return UIApplicationShortcutIcon(type: .home)
        case .details: return UIApplicationShortcutIcon(type: .task)
        }
    }
}

struct ResponderOpenedFromShortcutEvent: ResponderEvent {}
