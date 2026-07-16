//
//  Responder.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Foundation

@MainActor
public protocol ResponderEvent {}

@MainActor
public protocol Responder: AnyObject {
    var nextEventResponder: (any Responder)? { get set }

    func handle(event: any ResponderEvent) async -> Bool
}
