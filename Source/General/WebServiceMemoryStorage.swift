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
    
    public func fetch(request: WebServiceBaseRequesting, completionHandler: @escaping (Date?, WebServiceStorageResponse) -> Void) {
        guard let request = request as? WebServiceRequestMemoryStoring, let key = request.keyForMemoryStorage else {
            completionHandler(nil, .error(WebServiceResponseError.notFoundData))
            return
        }
        
        if let storeData = mutex.synchronized({ memoryData[key] }) {
            if storeData.isRaw, let raw = storeData.data as? WebServiceStorageRawData {
                completionHandler(storeData.timeStamp, .rawData(raw))
            } else if storeData.isRaw == false {
                completionHandler(storeData.timeStamp, .value(storeData.data))
            } else {
                completionHandler(nil, .error(WebServiceResponseError.notFoundData))
            }
        } else {
            completionHandler(nil, .error(WebServiceResponseError.notFoundData))
        }
    }

    public func save(request: WebServiceBaseRequesting, rawData: WebServiceStorageRawData?, value: Any) {
        guard let request = request as? WebServiceRequestMemoryStoring,
            let key = request.keyForMemoryStorage else {
            return
        }
        let isRaw = request.useRawDataForMemoryStorage
        let storeData: StoreData
        if isRaw, let rawData = rawData {
            storeData = StoreData(data: rawData, isRaw: true, timeStamp: Date())
        } else if isRaw == false {
            storeData = StoreData(data: value, isRaw: false, timeStamp: Date())
        } else {
            return
        }

        mutex.synchronized {
            memoryData[key] = storeData
        }
    }
    
    public func delete(request: WebServiceBaseRequesting) {
        if let request = request as? WebServiceRequestMemoryStoring, let key = request.keyForMemoryStorage {
            mutex.synchronized {
                memoryData.removeValue(forKey: key)
            }
        }
    }
    
    public func deleteAll() {
        mutex.synchronized {
            memoryData.removeAll()
        }
    }
}
