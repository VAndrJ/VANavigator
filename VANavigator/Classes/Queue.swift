//
//  Queue.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 23.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Foundation

class Queue<T> {
    private var elements: [T] = []

    var isEmpty: Bool { elements.isEmpty }

    func enqueue(_ element: T) {
        elements.append(element)
    }

    func dequeue() -> T? {
        isEmpty ? nil : elements.removeFirst()
    }
}
