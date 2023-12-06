//
//  Responder.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Foundation

public protocol ResponderEvent {}

public protocol Responder: AnyObject {
    @MainActor
    var nextEventResponder: Responder? { get set }

    @MainActor
    func handle(event: ResponderEvent) async -> Bool
}
