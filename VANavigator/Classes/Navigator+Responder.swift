//
//  Navigator+Responder.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Foundation

public struct ResponderPoppedToExistingEvent: ResponderEvent {}

public struct ResponderClosedToExistingEvent: ResponderEvent {}

public struct ResponderReplacedWindowRootControllerEvent: ResponderEvent {}
