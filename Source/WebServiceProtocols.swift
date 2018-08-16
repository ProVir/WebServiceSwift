//
//  WebServiceProtocols.swift
//  WebServiceSwift 3.0.0
//
//  Created by Короткий Виталий (ViR) on 14.06.2017.
//  Updated to 3.0.0 by Короткий Виталий (ViR) on 20.06.2018.
//  Copyright © 2017 - 2018 ProVir. All rights reserved.
//

import Foundation

//MARK: Requests

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

/// Groups requests, protocol use for `WebServiceGroupProvider`.
public protocol WebServiceGroupRequests {
    /// List all type requests in group
    static var requestTypes: [WebServiceBaseRequesting.Type] { get }
}



//MARK: Support storages

/// Base protocol for all requests with support storages
public protocol WebServiceRequestBaseStoring: WebServiceBaseRequesting {
    var dataClassificationForStorage: AnyHashable { get }
}

public extension WebServiceRequestBaseStoring {
    var dataClassificationForStorage: AnyHashable { return WebServiceDefaultDataClassification }
}

/// Default data classification for storages.
public let WebServiceDefaultDataClassification = "default"

/// Data Source from custom types response with raw data from server. Used in storages when raw data as binary.
public protocol WebServiceRawDataSource {
    var binaryRawData: Data? { get }
}

//MARK: Delegates

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


//MARK: Provider

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


//MARK: Public Internal - endpoints and storages

/// Protocol for endpoint in WebService.
public protocol WebServiceEndpoint: class {
    
    /// Thread Dispatch Queue for `perofrmRequest()` and `cancelRequests()` methods.
    var queueForRequest: DispatchQueue? { get }
    
    /// Thread Dispatch Queue for `dataProcessing()` method with data from `performRequest()` method.
    var queueForDataProcessing: DispatchQueue? { get }
    
    /// Thread Dispatch Queue for `dataProcessing()` method with raw data from store.
    var queueForDataProcessingFromStorage: DispatchQueue? { get }
    
    #if os(iOS)
    /// When `true`, showed networkActivityIndicator in statusBar when requests in process.
    var useNetworkActivityIndicator: Bool { get }
    #endif
    
    
    /**
     Asks whether the request supports this endpoint.
     
     If `rawDataForRestoreFromStorage != nil`, after this method called `processRawDataFromStorage()` method.
     
     - Parameters:
        - request: Request for test.
        - rawDataTypeForRestoreFromStorage: If no nil - request restore raw data from storage with data.
     - Returns: If request support this endpoint - return true.
     */
    func isSupportedRequest(_ request: WebServiceBaseRequesting, rawDataTypeForRestoreFromStorage: Any.Type?) -> Bool
    
    /**
     Perform request to server. Need call `completionWithRawData` or `completionWithError` and only one. After performed `completionWithRawData`, `completionWithError` or canceled ignored other this closure.
     
     If `queueForRequest != nil`, thread use from `queueForRequest`, else default thread (usually main).
     
     - Parameters:
        - requestId: Unique id for request. ID generated always unique for all Endpoints and WebServices. Use for `canceledRequest()`.
        - request: Original request with data.
        - completionWithRawData: After success get data from server - call this closure with raw data from server.
        - data: Usually binary data and this data saved as rawData in storage.
        - completionWithError: Call if error get data from server or other error. 
        - error: Response as error.
     */
    func performRequest(requestId: UInt64,
                        request: WebServiceBaseRequesting,
                        completionWithRawData: @escaping (_ data:Any) -> Void,
                        completionWithError: @escaping (_ error:Error) -> Void)
    
    /**
     Preformed after canceled request.
     
     If `queueForRequest != nil`, thread use from `queueForRequest`, else default thread (usually main).
 
     - Parameter requestId: Id for canceled.
    */
    func canceledRequest(requestId: UInt64)
    
    /**
     Process data from server or store with rawData.
     
     For data from server (`fromStorage == false`): if `queueForDataHandler != nil`, thread use from `queueForDataHandler`, else default thread (usually main).
     
     For data from storage (`fromStorage == true`): use `queueForDataHandlerFromStorage` if != nil.
     
     - Parameters:
        - request: Original request.
        - rawData: Type data from closure request.completionWithData(). Usually binary Data.
        - fromStorage: If `true`: data from storage, else data from closure `request.completionWithData()`.
     
     - Throws: Error validation or proccess data from server to end data. Data from server (also rawData) don't save to storage.
     - Returns: Result data for response.
     */
    func dataProcessing(request: WebServiceBaseRequesting, rawData: Any, fromStorage: Bool) throws -> Any
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
        - isRawData: If data readed as raw type.
        - timeStamp: TimeStamp when saved from server (endpoint).
        - response: Result response enum with data. Can only be .data or .error. If not data - use .error(WebServiceResponseError.notFoundData)
     
     - Throws: Error request equivalent call `completionResponse(.error())` and not need call `completionResponse()`. The performance is higher with this error call.
     */
    func readData(request: WebServiceBaseRequesting, completionHandler: @escaping (_ isRawData: Bool, _ timeStamp: Date?, _ response: WebServiceAnyResponse) -> Void) throws
    
    /**
     Save data from server (endpoint). Usually call two - for raw and value (after processing) data.
     Warning: Usually used not in main thread.
     
     - Parameters: 
        - request: Original request. 
        - data: Data for save. Type may be raw or after processed.
        - isRaw: Type data for save.
    */
    func writeData(request: WebServiceBaseRequesting, data: Any, isRaw: Bool)
    
    
    /**
     Delete data in storage for concrete request.
     
     - Parameter request: Original request.
     */
    func deleteData(request: WebServiceBaseRequesting)
    
    /// Delete all data in storage.
    func deleteAllData()
}

