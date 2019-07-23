//
//  Storage.swift
//  WebServiceSwift 4.0.0
//
//  Created by Короткий Виталий (ViR) on 17/07/2019.
//  Copyright © 2017 - 2019 ProVir. All rights reserved.
//

import Foundation

/// Default data classification for storages.
public let WebServiceDefaultDataClassification = "default"

/// Base protocol for all requests with support storages
public protocol WebServiceRequestBaseStoring: WebServiceBaseRequesting {
    /// Data classification to distinguish between storage
    var dataClassificationForStorage: AnyHashable { get }
}

public extension WebServiceRequestBaseStoring {
    var dataClassificationForStorage: AnyHashable { return WebServiceDefaultDataClassification }
}

/// Protocol for requests with support storages as key -> value
public protocol WebServiceRequestEasyStoring: WebServiceRequestBaseStoring {
    /// Unique identificator for read and write data if current request support storage.
    var identificatorForStorage: String? { get }
}

/// Conform to protocol if requests support storages
public protocol WebServiceRequestBinaryValueStoring: WebServiceRequestBinaryValueBaseStoring, WebServiceRequesting {
    /**
     Encoding data from custom type to binary data.

     - Parameter value: Value from response.
     - Results: Binary data after encoding if supported.
     */
    func encodeToBinaryForStorage(value: ResultType) -> Data?

    /**
     Decoding from binary data to custom type.

     - Parameter data: Binary data from storage.
     - Results: Custom type after decoding if supported.
     */
    func decodeToValueFromStorage(binary: Data) throws -> ResultType?
}


/// No generic protocol for requests support storages
public protocol WebServiceRequestBinaryValueBaseStoring: WebServiceRequestEasyStoring {
    func encodeToBinaryForStorage(anyValue: Any) -> Data?
    func decodeToAnyValueFromStorage(binary: Data) throws -> Any?
}

public extension WebServiceRequestBinaryValueStoring {
    func encodeToBinaryForStorage(anyValue: Any) -> Data? {
        if let value = anyValue as? ResultType {
            return encodeToBinaryForStorage(value: value)
        } else {
            return nil
        }
    }

    func decodeToAnyValueFromStorage(binary: Data) throws -> Any? {
        return try decodeToValueFromStorage(binary: binary)
    }
}


/// Response from storage
public enum WebServiceStorageResponse {
    case rawData(WebServiceStorageRawData, Date?)
    case value(Any, Date?)
    case error(Error)
}

/**
 Protocol for storages in WebService. All requests need.
 The class must be thread safe.

 RawData - data without process, original data from server
 */
public protocol WebServiceStorage: class {

    /// Data classification support list. nil = support all.
    var supportDataClassification: Set<AnyHashable>? { get }

    /**
     Asks whether the request supports this storage.

     - Parameter request: Request for test.
     - Returns: If request support this storage - return true.
     */
    func isSupportedRequest(_ request: WebServiceBaseRequesting) -> Bool

    /**
     Read data from storage.

     - Parameters:
     - request: Original request.
     - completionHandler: After readed data need call with result data. This closure need call and only one. Be sure to call in the main thread.
     - response: Result response enum with data. If not data - use .error(WebServiceResponseError.notFoundData)
     */
    func fetch(request: WebServiceBaseRequesting, completionHandler: @escaping (_ response: WebServiceStorageResponse) -> Void)

    /**
     Save data from server (gateway).
     Warning: Usually used not in main thread.

     - Parameters:
     - request: Original request.
     - rawData: Raw data for save - universal type, need process in gateway
     - value: Value type for save, no need process in gateway
     */
    func save(request: WebServiceBaseRequesting, rawData: WebServiceStorageRawData?, value: Any)

    /**
     Delete data in storage for concrete request.

     - Parameter request: Original request.
     */
    func delete(request: WebServiceBaseRequesting)

    /// Delete all data in storage.
    func deleteAll()
}

