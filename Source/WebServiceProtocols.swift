//
//  WebServiceProtocols.swift
//  WebServiceSwift 2.2.0
//
//  Created by ViR (Короткий Виталий) on 14.06.2017.
//  Updated to 2.2.0 by ViR (Короткий Виталий) on 17.04.2018.
//  Copyright © 2017 ProVir. All rights reserved.
//

import Foundation

//MARK: Requests

/// Base protocol for all types request.
public protocol WebServiceBaseRequesting {
    /**
     Unique key for request or groups requests (Optional). Default: for Hashable Requests equal self Request, else without key (= nil).
     
     Use in `WebService.containsRequest()` and `WebService.cancelRequest()` methods.
     
     Requests with equal `requestKey` are a group and controls by together in the methods of `containsRequest()` and `cancelRequest()`.
    */
    var requestKey: AnyHashable? { get }
    
    /// Test to equal request and send error if this request in process and wait data from server. Default = `nil` - use `WebService.excludeDuplicateRequests`.
    var excludeDuplicate: Bool? { get }
}

public protocol WebServiceRequesting: WebServiceBaseRequesting {
    associatedtype ResultType

    /**
     Result type. Usually as constant. If use `enums`, you can `ResultType = Any` and return many `resultType`.
     Default don't implementation (use `typealias ResultType`)
     */
    var resultType: ResultType.Type { get }
}

public extension WebServiceBaseRequesting {
    var requestKey: AnyHashable? { return nil }
    var excludeDuplicate: Bool? { return nil }
}

public extension WebServiceBaseRequesting where Self: Equatable {
    var requestKey: AnyHashable? { return WebServiceRequestKeyWrapper(request: self) }
}

public extension WebServiceBaseRequesting where Self: Hashable {
    var requestKey: AnyHashable? { return self }
}

public extension WebServiceRequesting {
    var resultType: ResultType.Type { return ResultType.self }
}




//MARK: Internal - engines and storages

/// Protocol for engines in WebService.
public protocol WebServiceEngining: class {
    
    /// Thread Dispatch Queue for `request()` and `cancelRequest()` methods.
    var queueForRequest:DispatchQueue? { get }
    
    /// Thread Dispatch Queue for `dataHandler()` method with data from `request()` method.
    var queueForDataHandler:DispatchQueue? { get }
    
    /// Thread Dispatch Queue for `dataHandler()` method with data from store.
    var queueForDataHandlerFromStorage:DispatchQueue? { get }
    
    /// When `true`, showed networkActivityIndicator in statusBar when requests in process.
    var useNetworkActivityIndicator:Bool { get }
    
    
    
    /**
     Asks whether the request supports this engine.
     
     If `rawDataForRestoreFromStorage != nil`, after this method called `processRawDataFromStorage()` method.
     
     - Parameters:
        - request: Request for test.
        - rawDataForRestoreFromStorage: If no nil - request restore raw data from storage with data.
     - Returns: If request support this engine - return true.
     */
    func isSupportedRequest(_ request:WebServiceBaseRequesting, rawDataForRestoreFromStorage:Any?) -> Bool
    
    
    /**
     Request data from server. Need call `completionWithData` or `completionWithError` or `canceled` and only one.
     
     If `queueForRequest != nil`, thread use from `queueForRequest`, else default thread (usually main).
     
     - Parameters:
        - requestId: Unique id for request. ID generated always unique for all Engines and WebServices. Use for `cancelRequest()`.
        - request: Original request with data.
        - completionWithData: After success get data from server - call this closure with raw data from server.
        - data: Usually binary data and this data saved as rawData in storage.
        - completionWithError: Call if error get data from server or other error. 
        - error: Response as error.
        - canceled: Call after called method `cancelRequest()` if support this operation.
     */
    func performRequest(requestId:UInt64, request:WebServiceBaseRequesting,
                        completionWithData:@escaping (_ data:Any) -> Void,
                        completionWithError:@escaping (_ error:Error) -> Void,
                        canceled:@escaping () -> Void)
    
    
    
    /**
     Cancel request if this operation is supported. This method is optional.
     
     If `queueForRequest != nil`, thread use from `queueForRequest`, else default thread (usually main).
 
     - Parameter requestId: Id for canceled.
    */
    func cancelRequest(requestId:UInt64)
    
    
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
    func dataHandler(request:WebServiceBaseRequesting, data:Any, isRawFromStorage:Bool) throws -> Any?
}


/// Protocol for storages in WebService.
///
/// RawData - data without process, original data from server
public protocol WebServiceStoraging: class {
    
    /**
     Asks whether the request supports this storage.
     
     - Parameters:
     - request: Request for test.
     - Returns: If request support this storage - return true.
     */
    func isSupportedRequestForStorage(_ request:WebServiceBaseRequesting) -> Bool
    
    
    /**
     Read data from store.
     
     - Parameters:
        - request: Original request.
        - completionHandler: After readed data need call with result data. This closure need call and only one. Be sure to call in the main thread.
        - isRawData: If data readed as raw type
        - response: Result response enum with data. Can only be .data or .error. If not data - use .data(nil)
     
     - Throws: Error request equivalent call `completionResponse(.error())` and not need call `completionResponse()`. The performance is higher with this error call.
     */
    func readData(request:WebServiceBaseRequesting, completionHandler:@escaping (_ isRawData:Bool, _ response:WebServiceAnyResponse) -> Void) throws
    
    
    /**
     Save data from server. Usually call two - for raw data and processed.
     
     If write raw data - can not be executed in the main thread.
     
     - Parameters: 
        - request: Original request. 
        - data: Data for save. Type may be raw or after processed.
        - isRaw: Type data for save.
    */
    func writeData(request:WebServiceBaseRequesting, data:Any, isRaw:Bool)
}


