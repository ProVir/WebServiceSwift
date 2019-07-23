//
//  WebServiceMemoryStorage.swift
//  WebServiceSwift 4.0.0
//
//  Created by Короткий Виталий (ViR) on 18.06.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation

/// Simple store in memory for WebService
public class WebServiceMemoryStorage: WebServiceStorage {

    private var memoryData = [String: (Any, Date)]()
    private let mutex = PThreadMutexLock()
    private let storeRawData: Bool

    public let supportDataClassification: Set<AnyHashable>?

    /**
     Constructor with all settings store.
     
     - Parameters:
        - supportDataClassification: Data classification support list. Default - support all.
        - storeRawData: If true, stored raw data and need data processing when read. Default - false
     */
    public init(supportDataClassification: Set<AnyHashable>? = nil, storeRawData: Bool = false) {
        self.supportDataClassification = supportDataClassification
        self.storeRawData = storeRawData
    }
    
    // MARK: WebServiceStoraging
    public func isSupportedRequest(_ request: WebServiceBaseRequesting) -> Bool {
        guard let request = request as? WebServiceRequestEasyStoring else {
            return false
        }

        return request.identificatorForStorage != nil
    }
    
    public func fetch(request: WebServiceBaseRequesting, completionHandler: @escaping (WebServiceStorageResponse) -> Void) {
        guard let request = request as? WebServiceRequestEasyStoring, let identificator = request.identificatorForStorage else {
            completionHandler(.error(WebServiceResponseError.notFoundData))
            return
        }

        if let (data, timeStamp) = mutex.synchronized({ memoryData[identificator] }) {
            if storeRawData {
                if let raw = data as? WebServiceStorageRawData {
                    completionHandler(.rawData(raw, timeStamp))
                } else {
                    completionHandler(.error(WebServiceResponseError.notFoundData))
                }
            } else {
                completionHandler(.value(data, timeStamp))
            }
        } else {
            completionHandler(.error(WebServiceResponseError.notFoundData))
        }
    }

    public func save(request: WebServiceBaseRequesting, rawData: WebServiceStorageRawData?, value: Any) {
        guard let request = request as? WebServiceRequestEasyStoring, let identificator = request.identificatorForStorage else {
            return
        }

        let data: Any
        let timeStamp = Date()
        if storeRawData {
            if let rawData = rawData {
                data = rawData
            } else {
                return
            }
        } else {
            data = value
        }

        mutex.synchronized {
            memoryData[identificator] = (data, timeStamp)
        }
    }
    
    public func delete(request: WebServiceBaseRequesting) {
        if let request = request as? WebServiceRequestEasyStoring, let identificator = request.identificatorForStorage {
            mutex.synchronized {
                memoryData.removeValue(forKey: identificator)
            }
        }
    }
    
    public func deleteAll() {
        mutex.synchronized {
            memoryData.removeAll()
        }
    }
}
