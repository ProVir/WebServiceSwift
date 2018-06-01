//
//  PThreadMutexLock.swift
//  WebServiceExample
//
//  Created by Короткий Виталий on 01.06.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation

internal class PThreadMutexLock: NSObject, NSLocking {
    private var mutex = pthread_mutex_t()
    
    override init() {
        super.init()
        
        pthread_mutex_init(&mutex, nil)
    }
    
    deinit {
        pthread_mutex_destroy(&mutex)
    }
    
    func lock() {
        pthread_mutex_lock(&mutex)
    }
    
    func unlock() {
        pthread_mutex_unlock(&mutex)
    }
    
    @discardableResult
    func synchronized<T>(_ handler: () throws -> T) rethrows -> T {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        return try handler()
    }
}
