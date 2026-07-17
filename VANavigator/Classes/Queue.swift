//
//  Queue.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 23.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import Foundation

struct Queue<T> {
    private var elements: [T?] = []
    private var headIndex = 0

    var isEmpty: Bool { headIndex == elements.count }

    mutating func enqueue(_ element: T) {
        elements.append(element)
    }

    mutating func dequeue() -> T? {
        guard !isEmpty else { return nil }

        let element = elements[headIndex]
        elements[headIndex] = nil
        headIndex += 1
        compactStorageIfNeeded()

        return element
    }

    private mutating func compactStorageIfNeeded() {
        if isEmpty {
            elements.removeAll(keepingCapacity: true)
            headIndex = 0
        } else if headIndex >= 64, headIndex >= elements.count / 2 {
            elements.removeFirst(headIndex)
            headIndex = 0
        }
    }
}
