//
//  DispatchQueueLock.swift
//  WebServiceSwift
//
//  Created by Vitalii Korotkii on 18/11/2019.
//  Copyright © 2019 ProVir. All rights reserved.
//

import Foundation

struct DispatchQueueLock {
    let label: String
    let concurrentRead: Bool

    private let queue: DispatchQueue

    init(label: String, concurrentRead: Bool = true) {
        self.label = label
        self.concurrentRead = concurrentRead
        self.queue = DispatchQueue(label: label, attributes: concurrentRead ? .concurrent : [])
    }

    @discardableResult
    func sync<T>(onlyRead: Bool = false, _ handler: () throws -> T) rethrows -> T {
        if onlyRead {
            return try read(handler)
        } else {
            return try write(handler)
        }
    }

    @discardableResult
    func read<T>(_ handler: () throws -> T) rethrows -> T {
        return try queue.sync(execute: handler)
    }

    @discardableResult
    func write<T>(_ handler: () throws -> T) rethrows -> T {
        if concurrentRead {
            return try queue.sync(flags: .barrier, execute: handler)
        } else {
            return try queue.sync(execute: handler)
        }
    }
}
