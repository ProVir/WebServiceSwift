//
//  WebServiceRequestProvider.swift
//  WebServiceSwift 2.2.1
//
//  Created by ViR (Короткий Виталий) on 24.04.2018.
//  Updated to 2.2.1 by ViR (Короткий Виталий) on 20.05.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation

/// Provider for single request type.
public class WebServiceRequestProvider<RequestType: WebServiceRequesting>: WebServiceProvider {
    fileprivate let service: WebService
    
    public required init(webService: WebService) {
        self.service = webService
    }
    
    /// Default delegate for responses. Apply before call new request.
    public weak var delegate: WebServiceDelegate?
    
    
    // MARK: General control requests
    
    /**
     Returns a Boolean value indicating whether the current queue contains the given request.
     
     - Parameter request: The request to find in the current queue.
     - Returns: `true` if the request was found in the current queue; otherwise, `false`.
     */
    public func containsRequest(request: RequestType) -> Bool {
        return service.containsRequest(request: request)
    }
    
    /**
     Returns a Boolean value indicating whether the current queue contains the given request.
     
     - Parameter requestKey: The requestKey to find in the current queue.
     - Returns: `true` if the request with requestKey was found in the current queue; otherwise, `false`.
     */
    public func containsRequest(requestKey: AnyHashable?) -> Bool {
        return service.containsRequest(requestKey: requestKey)
    }
    
    /**
     Returns a Boolean value indicating whether the current queue contains the given requests.
     
     - Returns: `true` if one request with current type was found in the current queue; otherwise, `false`.
     */
    public func containsRequests() -> Bool {
        return service.containsRequest(requestType: RequestType.self)
    }
    
    /**
     Cancel all requests with equal this request.
     
     Signal cancel send to engine, but real canceled implementation in engine.
     
     - Parameter request: The request to find in the current queue.
     */
    public func cancelRequests(request: RequestType) {
        service.cancelRequests(request: request)
    }
    
    /**
     Cancel all requests with requestKey.
     
     Signal cancel send to engine, but real canceled implementation in engine.
     
     - Parameter requestKey: The requestKey to find in the current queue.
     */
    public func cancelRequests(requestKey: AnyHashable?) {
        service.cancelRequests(requestKey: requestKey)
    }
    
    /**
     Cancel all requests current type in current queue.
     
     Signal cancel send to engine, but real canceled implementation in engine.
     */
    public func cancelAllRequests() {
        service.cancelRequests(requestType: RequestType.self)
    }
    
    
    // MARK: Requests with closure
    
    /**
     Request for server (and to storage, if need). Response result in closure.
     
     - Parameters:
     - request: The request data.
     - dataFromStorage: Optional. Closure for read data from storage. if read data after data from server - cloure not call. If `closure == nil`, data not read from storage.
     - completionResponse: Optional. Closure for response result from server.
     */
    public func performRequest(_ request: RequestType, dataFromStorage: ((_ data: RequestType.ResultType) -> Void)? = nil, completionResponse: @escaping (_ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        service.performRequest(request, dataFromStorage: dataFromStorage, completionResponse: completionResponse)
    }
    
    /**
     Request for only storage. Response result in closure.
     
     - Parameters:
     - request: The request data.
     - completionResponse: Closure for read data from storage.
     - response: result read from storage.
     */
    public func readStorage(_ request: RequestType, completionResponse: @escaping (_ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        service.readStorage(request, completionResponse: completionResponse)
    }
    
    
    // MARK: Requests with delegates
    
    /**
     Request for server (and to storage, if need). Response result for delegate in helper or `WebService.delegate`.
     
     - Parameters:
     - request: The request data.
     - includeResponseStorage: `true` if need read data from storage. if read data after data from server - delegate not call. Default: false.
     */
    public func performRequest(_ request: RequestType, includeResponseStorage: Bool = false) {
        service.performRequest(request, includeResponseStorage: includeResponseStorage, customDelegate: delegate)
    }
    
    /**
     Request for only storage. Response result for delegate in helper or `WebService.delegate`.
     
     - Parameter request: The request data.
     */
    public func readStorage(_ request: RequestType) {
        service.readStorage(request, customDelegate: delegate)
    }
}
