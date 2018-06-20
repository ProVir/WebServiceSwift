//
//  WebServiceProtocols.swift
//  WebServiceSwift 3.0.0
//
//  Created by Короткий Виталий (ViR) on 14.06.2017.
//  Updated to 3.0.0 by Короткий Виталий (ViR) on 19.06.2018.
//  Copyright © 2017 ProVir. All rights reserved.
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


//MARK: Support storages

/// Base protocol for all requests with support storages
public protocol WebServiceRequestBaseStoring: WebServiceBaseRequesting {
    var dataClassificationForStorage: AnyHashable { get }
}

/// Default data classification for storages.
public let WebServiceDefaultDataClassification = "default"

/// Data Source from custom types response with raw data from server. Used in storages when raw data as binary.
public protocol WebServiceRawDataSource {
    var binaryRawData: Data? { get }
}



//MARK: Provider

/// Base protocol for providers
public protocol WebServiceProvider {
    init(webService: WebService)
}

public extension WebService {
    /// Create provider with this WebService
    func getProvider<T: WebServiceProvider>() -> T {
        return T.init(webService: self)
    }
}


//MARK: Public Internal - endpoints and storages

/// Protocol for endpoint in WebService.
public protocol WebServiceEndpoint: class {
    
    /// Thread Dispatch Queue for `perofrmRequest()` and `cancelRequests()` methods.
    var queueForRequest: DispatchQueue? { get }
    
    /// Thread Dispatch Queue for `dataHandler()` method with data from `performRequest()` method.
    var queueForDataHandler: DispatchQueue? { get }
    
    /// Thread Dispatch Queue for `dataHandler()` method with raw data from store.
    var queueForDataHandlerFromStorage: DispatchQueue? { get }
    
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
     Request data from server. Need call `completionWithData` or `completionWithError` or `canceled` and only one.
     
     If `queueForRequest != nil`, thread use from `queueForRequest`, else default thread (usually main).
     
     - Parameters:
        - requestId: Unique id for request. ID generated always unique for all Endpoints and WebServices. Use for `cancelRequest()`.
        - request: Original request with data.
        - completionWithData: After success get data from server - call this closure with raw data from server.
        - data: Usually binary data and this data saved as rawData in storage.
        - completionWithError: Call if error get data from server or other error. 
        - error: Response as error.
        - canceled: Call after called method `cancelRequest()` if support this operation.
     */
    func performRequest(requestId: UInt64,
                        request: WebServiceBaseRequesting,
                        completionWithRawData: @escaping (_ data:Any) -> Void,
                        completionWithError: @escaping (_ error:Error) -> Void)
    

    /**
     Cancel request if this operation is supported. This method is optional.
     
     If `queueForRequest != nil`, thread use from `queueForRequest`, else default thread (usually main).
 
     - Parameter requestId: Id for canceled.
    */
    func canceledRequest(requestId: UInt64)
    
    
    /**
     Process data from server or store (rawData). 
     
     For data from server (`isRawFromStorage == false`): if `queueForDataHandler != nil`, thread use from `queueForDataHandler`, else default thread (usually main).
     
     For data from storage (`isRawFromStorage == true`): use `queueForDataHandlerFromStorage` if != nil.
     
     - Parameters:
        - request: Original request.
        - data: Type data form closure request.completionWithData(). Usually binary Data.
        - isRawFromStorage: If `true`: data from storage, else data from closure `request.completionWithData()`.
     
     - Throws: Error proccess data from server to end data. Data from server (rawData) don't save to storage.
     - Returns: Result data for response. If == nil, data from server (rawData) don't save to storage.
     */
    func dataProcessing(request: WebServiceBaseRequesting, rawData: Any, fromStorage: Bool) throws -> Any?
}


/// Protocol for storages in WebService.
///
/// RawData - data without process, original data from server
public protocol WebServiceStorage: class {
    
    /**
     Asks whether the request supports this storage.
     
     - Parameters:
     - request: Request for test.
     - Returns: If request support this storage - return true.
     */
    func isSupportedRequestForStorage(_ request: WebServiceBaseRequesting) -> Bool
    
    
    /**
     Read data from store.
     
     - Parameters:
        - request: Original request.
        - completionHandler: After readed data need call with result data. This closure need call and only one. Be sure to call in the main thread.
        - isRawData: If data readed as raw type
        - response: Result response enum with data. Can only be .data or .error. If not data - use .data(nil)
     
     - Throws: Error request equivalent call `completionResponse(.error())` and not need call `completionResponse()`. The performance is higher with this error call.
     */
    func readData(request: WebServiceBaseRequesting, completionHandler: @escaping (_ isRawData: Bool, _ timeStamp: Date?, _ response: WebServiceAnyResponse) -> Void) throws
    
    
    /**
     Save data from server. Usually call two - for raw data and processed.
     
     If write raw data - can not be executed in the main thread.
     
     - Parameters: 
        - request: Original request. 
        - data: Data for save. Type may be raw or after processed.
        - isRaw: Type data for save.
    */
    func writeData(request: WebServiceBaseRequesting, data: Any, isRaw: Bool)
}


