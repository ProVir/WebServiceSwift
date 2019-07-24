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
    private struct StoreDate {
        let data: Any
        let isRaw: Bool
        let timeStamp: Date
    }

    private var memoryData = [String: StoreDate]()
    private let mutex = PThreadMutexLock()

    public let supportDataClassification: Set<AnyHashable>?

    /**
     Constructor with all settings store.
     
     - Parameters:
        - supportDataClassification: Data classification support list. Default - support all.
     */
    public init(supportDataClassification: Set<AnyHashable>? = nil) {
        self.supportDataClassification = supportDataClassification
    }
    
    // MARK: WebServiceStoraging
    public func isSupportedRequest(_ request: WebServiceBaseRequesting) -> Bool {
        return identificatorForStorage(request: request) != nil
    }
    
    public func fetch(request: WebServiceBaseRequesting, completionHandler: @escaping (WebServiceStorageResponse) -> Void) {
        guard let identificator = identificatorForStorage(request: request) else {
            completionHandler(.error(WebServiceResponseError.notFoundData))
            return
        }

        if let storeData = mutex.synchronized({ memoryData[identificator] }) {
            if storeData.isRaw {
                if let raw = storeData.data as? WebServiceStorageRawData {
                    completionHandler(.rawData(raw, storeData.timeStamp))
                } else {
                    completionHandler(.error(WebServiceResponseError.notFoundData))
                }
            } else {
                completionHandler(.value(storeData.data, storeData.timeStamp))
            }
        } else {
            completionHandler(.error(WebServiceResponseError.notFoundData))
        }
    }

    public func save(request: WebServiceBaseRequesting, rawData: WebServiceStorageRawData?, value: Any) {
        guard let identificator = identificatorForStorage(request: request) else {
            return
        }

        let data: Any
        let isRaw: Bool
        let timeStamp = Date()
        if request is WebServiceRequestEasyRawStoring, let rawData = rawData {
            data = rawData
            isRaw = true

        } else if request is WebServiceRequestEasyValueBaseStoring {
            data = value
            isRaw = false

        } else {
            return
        }

        mutex.synchronized {
            memoryData[identificator] = StoreDate(data: data, isRaw: isRaw, timeStamp: timeStamp)
        }
    }
    
    public func delete(request: WebServiceBaseRequesting) {
        if let identificator = identificatorForStorage(request: request) {
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

    private func identificatorForStorage(request: WebServiceBaseRequesting) -> String? {
        if let request = request as? WebServiceRequestEasyRawStoring {
            return request.identificatorForStorage
        } else if let request = request as? WebServiceRequestEasyValueBaseStoring {
            return request.identificatorForStorage
        } else {
            return nil
        }
    }
}
