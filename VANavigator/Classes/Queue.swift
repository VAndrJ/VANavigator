//
//  Queue.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 23.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Foundation

struct Queue<T> {
    private var elements: [T] = []

    var isEmpty: Bool { elements.isEmpty }

    mutating func enqueue(_ element: T) {
        elements.append(element)
    }

    mutating func dequeue() -> T? {
        return isEmpty ? nil : elements.removeFirst()
    }
}
