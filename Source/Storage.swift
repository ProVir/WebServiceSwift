//
//  Storage.swift
//  WebServiceSwift 4.0.0
//
//  Created by Короткий Виталий (ViR) on 17/07/2019.
//  Copyright © 2017 - 2019 ProVir. All rights reserved.
//

import Foundation

public protocol NetworkStorage: NetworkBaseStorage {
    associatedtype RequestType: NetworkRequestBaseStorable

    func fetch(request: NetworkRequestBaseStorable, completion: @escaping (_ result: NetworkStorageFetchResult) -> Void)

    func save(request: NetworkRequestBaseStorable, saved: Date, expired: Date?, rawData: NetworkStorageRawData?, value: Any, completion: @escaping (NetworkStorageSaveResult) -> Void)

    func delete(request: NetworkRequestBaseStorable)
}

/**
 Protocol for storages in WebService. All requests need.
 The class must be thread safe.

 RawData - data without process, original data from server
 */
public protocol NetworkBaseStorage: class {

    /// Data classification support list. nil = support all.
    var supportDataClassification: Set<AnyHashable>? { get }

    /// Default age limit for unknown case in requests.
    var defaultAgeLimit: NetworkRequestStoreAgeLimit { get }

    /**
     Asks whether the request supports this storage.

     - Parameter request: Request for test.
     - Returns: If request support this storage - return true.
     */
    func isSupportedRequest(_ request: NetworkRequestBaseStorable) -> Bool

    /**
     Read data from storage.

     - Parameters:
     - request: Original request.
     - completionHandler: After readed data need call with result data. This closure need call and only one. Be sure to call in the main thread.
     - result: Result response enum with data.
     */
    func fetch(baseRequest request: NetworkRequestBaseStorable, completion: @escaping (_ result: NetworkStorageFetchResult) -> Void)

    /**
     Save data from server (gateway).
     Warning: Usually used not in main thread.

     - Parameters:
        - request: Original request.
        - expired: Expired time for valid data
        - rawData: Raw data for save - universal type, need process in gateway
        - value: Value type for save, no need process in gateway
     */
    func save(baseRequest request: NetworkRequestBaseStorable, saved: Date, expired: Date?, rawData: NetworkStorageRawData?, value: Any, completion: @escaping (NetworkStorageSaveResult) -> Void)

    /**
     Delete data in storage for concrete request.

     - Parameter request: Original request.
     */
    func delete(baseRequest request: NetworkRequestBaseStorable)

    /// Delete all data in storage.
    func deleteAll()
}

public extension NetworkStorage {
    func isSupportedRequest(_ request: NetworkRequestBaseStorable) -> Bool {
        return request is RequestType
    }

    func fetch(baseRequest request: NetworkRequestBaseStorable, completion: @escaping (_ result: NetworkStorageFetchResult) -> Void) {
        guard let request = request as? RequestType else {
            completion(.failure(NetworkError.notSupportRequest))
            return
        }

        fetch(request: request, completion: completion)
    }

    func save(baseRequest request: NetworkRequestBaseStorable, saved: Date, expired: Date?, rawData: NetworkStorageRawData?, value: Any, completion: @escaping (NetworkStorageSaveResult) -> Void) {
        guard let request = request as? RequestType else {
            return
        }

        save(request: request, saved: saved, expired: expired, rawData: rawData, value: value, completion: completion)
    }

    func delete(baseRequest request: NetworkRequestBaseStorable) {
        guard let request = request as? RequestType else {
            return
        }

        delete(request: request)
    }
}
