//
//  Storage.swift
//  WebServiceSwift 4.0.0
//
//  Created by Короткий Виталий (ViR) on 17/07/2019.
//  Copyright © 2017 - 2019 ProVir. All rights reserved.
//

import Foundation


/**
 Protocol for storages in WebService. All requests need.
 The class must be thread safe.

 RawData - data without process, original data from server
 */
public protocol NetworkStorage: class {

    /// Data classification support list. nil = support all.
    var supportDataClassification: Set<AnyHashable>? { get }

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
     - response: Result response enum with data. 
     */
    func fetch(request: NetworkRequestBaseStorable, completionHandler: @escaping (_ response: NetworkStorageFetchResponse) -> Void)

    /**
     Save data from server (gateway).
     Warning: Usually used not in main thread.

     - Parameters:
     - request: Original request.
     - rawData: Raw data for save - universal type, need process in gateway
     - value: Value type for save, no need process in gateway
     */
    func save(request: NetworkRequestBaseStorable, rawData: NetworkStorageRawData?, value: Any)

    /**
     Delete data in storage for concrete request.

     - Parameter request: Original request.
     */
    func delete(request: NetworkRequestBaseStorable)

    /// Delete all data in storage.
    func deleteAll()
}

