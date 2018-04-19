//
//  WebServiceProvider.swift
//  WebServiceSwift 2.2.0
//
//  Created by Короткий Виталий on 11.04.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation


///Generic Provider for WebService with concrete type Requests and Response
open class WebServiceProvider<RequestType: WebServiceRequesting> {
    private let service: WebService
    

    /// Constructor for WebServiceProvider. Require setuped WebService.
    public init(webService:WebService) {
        self.service = webService
    }
    
    
    // MARK: Control requests
    
    /**
     Returns a Boolean value indicating whether the current queue contains the given request.
     
     - Parameter request: The request to find in the current queue.
     - Returns: `true` if the request was found in the current queue; otherwise, `false`.
     */
    public func containsRequest(request:RequestType) -> Bool {
        return service.containsRequest(request: request)
    }
    
    /**
     Returns a Boolean value indicating whether the current queue contains the given request.
     
     - Parameter requestKey: The requestKey to find in the current queue.
     - Returns: `true` if the request with requestKey was found in the current queue; otherwise, `false`.
     */
    public func containsRequest(requestKey:AnyHashable?) -> Bool {
        return service.containsRequest(requestKey: requestKey)
    }
    
    /**
     Cancel all requests with equal this request.
     
     Signal cancel send to engine, but real canceled implementation in engine.
     
     - Parameter request: The request to find in the current queue.
     */
    public func cancelRequest(request:RequestType) {
        service.cancelRequest(request: request)
    }
    
    
    /**
     Cancel all requests with requestKey.
     
     Signal cancel send to engine, but real canceled implementation in engine.
     
     - Parameter requestKey: The requestKey to find in the current queue.
     */
    public func cancelRequest(requestKey:AnyHashable?) {
        service.cancelRequest(requestKey: requestKey)
    }
    
    /// Cancel all requests in current queue.
    ///
    /// Signal cancel send to engine, but real canceled implementation in engine.
    public func cancelAllRequests() {
        service.cancelAllRequests()
    }
    
    
    // MARK: Requests with closure
    
    /**
     Request for server (and to storage, if need). Response result in closure.
     
     - Parameters:
     - request: The request data.
     - dataFromStorage: Optional. Closure for read data from storage. if read data after data from server - cloure not call. If `closure == nil`, data not read from storage.
     - completionResponse: Optional. Closure for response result from server.
     */
    public func request<T>(_ request:RequestType, dataFromStorage:((_ data:T) -> Void)? = nil, completionResponse:((_ response:WebServiceTypeResponse<T>) -> Void)?) {
        //DataFromStorage
        let dataFromStorageInternal:((_ data:Any) -> Void)?
        if let dataFromStorage = dataFromStorage {
            dataFromStorageInternal = { if let data = $0 as? T { dataFromStorage(data) } }
        } else {
            dataFromStorageInternal = nil
        }
        
        
        //CompletionResponse
        let completionResponseInternal:((_ response:WebServiceResponse) -> Void)?
        if let completionResponse = completionResponse {
            completionResponseInternal = { completionResponse(WebServiceTypeResponse<T>.init(response: $0)) }
        } else {
            completionResponseInternal = nil
        }
        
        //Real request
        service.request(request, dataFromStorage: dataFromStorageInternal, completionResponse: completionResponseInternal)
    }
    
    /**
     Request for only storage. Response result in closure.
     
     - Parameters:
     - request: The request data.
     - completionResponse: Closure for read data from storage.
     - response: result read from storage.
     */
    public func requestReadStorage<T>(_ request:RequestType, completionResponse:@escaping (_ response:WebServiceTypeResponse<T>) -> Void) {
        //CompletionResponse
        let completionResponseInternal:(_ response:WebServiceResponse) -> Void = { completionResponse(WebServiceTypeResponse<T>.init(response: $0)) }
        
        //Real request
        service.requestReadStorage(request, completionResponse: completionResponseInternal)
    }
    
    
    
    // MARK: Requests with delegates
    
    /**
     Request for server (and to storage, if need). Response result in default or custom delegate.
     
     - Parameters:
     - request: The request data.
     - includeResponseStorage: `true` if need read data from storage. if read data after data from server - delegate not call. Default: false.
     - customDelegate: Optional. Unique delegate for current request.
     */
    public func request(_ request:RequestType, includeResponseStorage:Bool = false, standartDelegate:WebServiceDelegate? = nil) {
        service.request(request, includeResponseStorage: includeResponseStorage, customDelegate: standartDelegate ?? self)
    }
    
    
    /**
     Request for only storage. Response result in default or custom delegate.
     
     - Parameters:
     - request: The request data.
     - customDelegate: Optional. Unique delegate for current request.
     */
    public func requestReadStorage(_ request:RequestType, standartDelegate:WebServiceDelegate? = nil) {
        service.requestReadStorage(request, customDelegate: standartDelegate ?? self)
    }
    
    
    
    //MARK: Override
    open func webServiceResponse(request: RequestType, isStorageRequest: Bool, response: WebServiceResponse) {
        
    }
}


//MARK: - Internal
extension WebServiceProvider: WebServiceDelegate {
    public func webServiceResponse(request: WebServiceRequesting, isStorageRequest: Bool, response: WebServiceResponse) {
        if let request = request as? RequestType {
            webServiceResponse(request: request, isStorageRequest: isStorageRequest, response: response)
        }
    }
}

