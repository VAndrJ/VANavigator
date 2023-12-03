//
//  ShortcutService.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import UIKit
import VANavigator

final class ShortcutsService {

    func addShortcuts() {
        UIApplication.shared.shortcutItems?.removeAll()
        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(type: .main),
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

    var title: String {
        switch self {
        case .main: return "Main"
        }
    }
    var subtitle: String? {
        switch self {
        case .main: return "Replace root with new main"
        }
    }
    var icon: UIApplicationShortcutIcon {
        switch self {
        case .main: return UIApplicationShortcutIcon(type: .home)
        }
    }
}

struct ResponderOpenedFromShortcutEvent: ResponderEvent {}
