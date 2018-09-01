//
//  WebServiceMemoryStorage.swift
//  WebServiceSwift 3.0.0
//
//  Created by Короткий Виталий (ViR) on 18.06.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation

/// Base protocol for requests support store data in memory.
public protocol WebServiceRequestMemoryStoring: WebServiceRequestBaseStoring {
    
    /// Key for storing data in memory if support
    var keyForMemoryStorage: AnyHashable? { get }
    
    /// If 'true' - ignore value data and store as raw data. Default: false.
    var useRawDataForMemoryStorage: Bool { get }
}

public extension WebServiceRequestMemoryStoring {
    var useRawDataForMemoryStorage: Bool { return false }
}


/// Simple store in memory for WebService
public class WebServiceMemoryStorage: WebServiceStorage {
    
    /**
     Constructor with all settings store.
     
     - Parameter supportDataClassification: Data classification support list. Default: support all.
     */
    public init(supportDataClassification: Set<AnyHashable> = []) {
        self.supportDataClassification = supportDataClassification
    }
    
    
    // MARK: Private data
    private struct StoreData {
        var data: Any
        var isRaw: Bool
        var timeStamp: Date?
    }
    
    private var memoryData = [AnyHashable: StoreData]()
    private let mutex = PThreadMutexLock()
    
    // MARK: WebServiceStoraging
    public var supportDataClassification: Set<AnyHashable>
    
    public func isSupportedRequest(_ request: WebServiceBaseRequesting) -> Bool {
        guard let request = request as? WebServiceRequestMemoryStoring else {
            return false
        }
        
        return request.keyForMemoryStorage != nil
    }
    
    public func readData(request: WebServiceBaseRequesting, completionHandler: @escaping (Bool, Date?, WebServiceAnyResponse) -> Void) throws {
        guard let request = request as? WebServiceRequestMemoryStoring, let key = request.keyForMemoryStorage else {
            throw WebServiceResponseError.notFoundData
        }
        
        if let storeData = mutex.synchronized({ memoryData[key] }) {
            completionHandler(storeData.isRaw, storeData.timeStamp, .data(storeData.data))
        } else {
            throw WebServiceResponseError.notFoundData
        }
    }
    
    public func writeData(request: WebServiceBaseRequesting, data: Any, isRaw: Bool) {
        guard let request = request as? WebServiceRequestMemoryStoring,
            let key = request.keyForMemoryStorage,
            request.useRawDataForMemoryStorage == isRaw else {
            return
        }
        
        let storeData = StoreData(data: data, isRaw: isRaw, timeStamp: Date())
        mutex.synchronized {
            memoryData[key] = storeData
        }
    }
    
    public func deleteData(request: WebServiceBaseRequesting) {
        if let request = request as? WebServiceRequestMemoryStoring, let key = request.keyForMemoryStorage {
            mutex.synchronized {
                memoryData.removeValue(forKey: key)
            }
        }
    }
    
    public func deleteAllData() {
        mutex.synchronized {
            memoryData.removeAll()
        }
    }
}
