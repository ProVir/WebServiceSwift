//
//  WebServiceProtocols.swift
//  WebService 2.0.swift
//
//  Created by ViR (Короткий Виталий) on 14.06.17.
//  Copyright © 2017 ProVir. All rights reserved.
//

import Foundation



/// Base protocol for all types request.
public protocol WebServiceRequesting {
    
    /**
     Unique key for request or groups requests.
     
     Use in `WebService.containsRequest()` and `WebService.cancelRequest()` methods.
     
     Requests with equal `requestKey` are a group and controls by together in the methods of `containsRequest()` and `cancelRequest()`.
    */
    var requestKey:AnyHashable? { get }
}


/// Protocol for engines in WebService.
public protocol WebServiceEngining: class {
    
    /**
     Asks whether the request supports this engine.
     
     If `rawDataForRestoreFromStorage != nil`, after this method called `processRawDataFromStorage()` method.
     
     - Parameters:
        - request: Request for test.
        - rawDataForRestoreFromStorage: If no nil - request restore raw data from storage with data.
     - Returns: If request support this engine - return true.
     */
    func isSupportedRequest(_ request:WebServiceRequesting, rawDataForRestoreFromStorage:Any?) -> Bool
    
    
    /**
     Request for server
     
     - Parameters: 
        - requestId: Unique id for request. ID generated always unique for all Engines and WebServices. Use for `cancelRequest()`.
        - request: Original request with data.
        - saveRawDataToStorage: When success request - call for save raw data. It is not necessary to call in the main thread.
        - rawData: Usually binary Data from server (As in `WebServiceSimpleStore`).
        - completionResponse: When complete request - need call. This closure need call and only one. Be sure to call in the main thread.
        - response: Result response enum with data.
     
     - Throws: Error request equivalent call `completionResponse(.error())` and not need call `completionResponse()`. The performance is higher with this error call.
     */
    func request(requestId:UInt64, request:WebServiceRequesting, saveRawDataToStorage:@escaping (_ rawData:Any) -> Void, completionResponse:@escaping (_ response:WebServiceResponse) -> Void) throws
    
    
    /**
     Cancel request if this operation is supported. This method is optional.
 
     - Parameter requestId: Id for canceled.
    */
    func cancelRequest(requestId:UInt64)
    
    
    /**
     Restore raw data from store helper.
     
     - Parameters:
        - rawData: Usually binary Data (As in `WebServiceSimpleStore`).
        - request: Original request for storage.
        - completeResponse: After process rawData need call with result. This closure need call and only one. Be sure to call in the main thread.
        - response: Result response enum with data. Can only be .data or .error
     
    - Throws: Error request equivalent call `completionResponse(.error())` and not need call `completionResponse()`. The performance is higher with this error call.
    */
    func processRawDataFromStorage(rawData:Any, request:WebServiceRequesting, completeResponse:@escaping (_ response:WebServiceResponse) -> Void) throws
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
    func isSupportedRequestForStorage(_ request:WebServiceRequesting) -> Bool
    
    
    /**
     Read data from store.
     
     - Parameters:
        - request: Original request.
        - completionHandler: After readed data need call with result data. This closure need call and only one. Be sure to call in the main thread.
        - isRawData: If data readed as raw type
        - response: Result response enum with data. Can only be .data or .error. If not data - use .data(nil)
     
     - Throws: Error request equivalent call `completionResponse(.error())` and not need call `completionResponse()`. The performance is higher with this error call.
     */
    func readData(request:WebServiceRequesting, completionHandler:@escaping (_ isRawData:Bool, _ response:WebServiceResponse) -> Void) throws
    
    
    /**
     Save data from server. Usually call two - for raw data and processed.
     
     If write raw data - can not be executed in the main thread.
     
     - Parameters: 
        - request: Original request. 
        - data: Data for save. Type may be raw or after processed.
        - isRaw: Type data for save.
    */
    func writeData(request:WebServiceRequesting, data:Any, isRaw:Bool)
}


