//
//  Navigator+Responder.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Foundation

/// Represents an event where the responder navigated back to an existing view controller.
public struct ResponderPoppedToExistingEvent: ResponderEvent {}

/// Represents an event where the responder closed and returned to an existing view controller.
public struct ResponderClosedToExistingEvent: ResponderEvent {}

/// Represents an event where the responder replaced the root view controller of the window.
public struct ResponderReplacedWindowRootControllerEvent: ResponderEvent {}
