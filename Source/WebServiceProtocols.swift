//
//  WebServiceProtocols.swift
//  WebServiceSwift 4.0.0
//
//  Created by Короткий Виталий (ViR) on 14.06.2017.
//  Updated to 3.0.0 by Короткий Виталий (ViR) on 04.09.2018.
//  Copyright © 2017 - 2018 ProVir. All rights reserved.
//

import Foundation

// MARK: Requests

/// Base protocol for all types request.
public protocol WebServiceBaseRequesting { }

/// Generic protocol with information result type for all types request.
public protocol WebServiceRequesting: WebServiceBaseRequesting {
    /// Type for response data when success. For data without data you can use Void or Any?
    associatedtype ResultType
}

/// Generic protocol without parameters for server and with information result type for all types request.
public protocol WebServiceEmptyRequesting: WebServiceRequesting {
    init()
}


// MARK: Support storages

/// Base protocol for all requests with support storages
public protocol WebServiceRequestBaseStoring: WebServiceBaseRequesting {
    var dataClassificationForStorage: AnyHashable { get }
}

public extension WebServiceRequestBaseStoring {
    var dataClassificationForStorage: AnyHashable { return WebServiceDefaultDataClassification }
}

/// Default data classification for storages.
public let WebServiceDefaultDataClassification = "default"

/// RawData for Gateway
public protocol WebServiceStorageRawData { }
extension Data: WebServiceStorageRawData { }

/// Response from gateway when success
public struct WebServiceGatewayResponse {
    let result: Any
    let rawDataForStorage: WebServiceStorageRawData?
}

/// Response from storage
public enum WebServiceStorageResponse {
    case rawData(WebServiceStorageRawData)
    case value(Any)
    case error(Error)
}

// MARK: Delegates

/// WebService Delegate for responses
public protocol WebServiceDelegate: class {
    
    /**
     Response from storage or server
     
     - Parameters:
     - request: Original request
     - key: key from `performRequest` method if have
     - isStorageRequest: Bool flag - response from storage or server
     - response: Response enum with results
     */
    func webServiceResponse(request: WebServiceBaseRequesting, key: AnyHashable?, isStorageRequest: Bool, response: WebServiceAnyResponse)
}


// MARK: Provider

/// Base protocol for providers
public protocol WebServiceProvider {
    init(webService: WebService)
}

public extension WebService {
    /// Create provider with this WebService
    func createProvider<T: WebServiceProvider>() -> T {
        return T.init(webService: self)
    }
}


// MARK: Gateways and storages

/// Protocol for gateway in WebService.
public protocol WebServiceGateway: class {
    /// Thread Dispatch Queue for `perofrmRequest()` and `cancelRequests()` methods.
    var queueForRequest: DispatchQueue? { get }
    
    /// Thread Dispatch Queue for `dataProcessingFromStorage()` method with raw data from storage.
    var queueForDataProcessingFromStorage: DispatchQueue? { get }
    
    #if os(iOS)
    /// When `true`, showed networkActivityIndicator in statusBar when requests in process.
    var useNetworkActivityIndicator: Bool { get }
    #endif

    /**
     Asks whether the request supports this gateway.
     
     If `rawDataTypeForRestoreFromStorage != nil`, after this method called `dataProcessingFromStorage(request:rawData:)` method.
     
     - Parameters:
        - request: Request for test.
        - forDataProcessingFromStorage: If no nil - request restore raw data from storage with data.
     - Returns: If request support this gateway - return true.
     */
    func isSupportedRequest(_ request: WebServiceBaseRequesting, forDataProcessingFromStorage rawDataType: WebServiceStorageRawData.Type?) -> Bool
    
    /**
     Perform request to server. Need call `completionWithRawData` and only one.
     
     If `queueForRequest != nil`, thread use from `queueForRequest`, else default thread (usually main).
     
     - Parameters:
        - requestId: Unique id for request. ID generated always unique for all Gateways and WebServices. Use for `canceledRequest()`.
        - request: Original request with data.
        - completionWithRawData: Result with raw data from server or error. RawData usually binary data and this data saved as rawData in storage.
     */
    func performRequest(requestId: UInt64, request: WebServiceBaseRequesting, completion: @escaping (Result<WebServiceGatewayResponse, Error>) -> Void)
    
    /**
     Preformed after canceled request.
     
     If `queueForRequest != nil`, thread use from `queueForRequest`, else default thread (usually main).
 
     - Parameter requestId: Id for canceled.
    */
    func canceledRequest(requestId: UInt64)
    
    /**
     Process raw data from storage.
     Used `queueForDataProcessingFromStorage` if != nil.
     
     - Parameters:
        - request: Original request.
        - rawData: Raw data from storage, usually binary Data.
     
     - Throws: Error proccess data from storage to result.
     - Returns: Result data.
     */
    func dataProcessingFromStorage(request: WebServiceBaseRequesting, rawData: WebServiceStorageRawData) throws -> Any
}


/**
 Protocol for storages in WebService. All requests need.
 The class must be thread safe.

 RawData - data without process, original data from server
 */
public protocol WebServiceStorage: class {
    
    /// Data classification support list. Empty = support all.
    var supportDataClassification: Set<AnyHashable> { get }
    
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
        - timeStamp: TimeStamp when saved from server (gateway).
        - response: Result response enum with data. If not data - use .error(WebServiceResponseError.notFoundData)
     */
    func fetch(request: WebServiceBaseRequesting, completionHandler: @escaping (_ timeStamp: Date?, _ response: WebServiceStorageResponse) -> Void)
    
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

