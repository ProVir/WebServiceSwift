//
//  WebServiceProvider.swift
//  WebServiceSwift 2.2.0
//
//  Created by Короткий Виталий on 11.04.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation



///Response type
public enum WebServiceProviderResponse<T> {
    case data(T)
    case error(Error)
    case canceledRequest
    case duplicateRequest
    
    /// Data if success response
    public func dataResponse() -> T? {
        switch self {
        case .data(let d): return d
        default: return nil
        }
    }
    
    /// Error if response completed with error
    public func errorResponse() -> Error? {
        switch self {
        case .error(let err): return err
        default: return nil
        }
    }
    
    /// Is canceled request
    public var isCanceled:Bool {
        switch self {
        case .canceledRequest: return true
        default: return false
        }
    }
    
    /// Error duplicate for request
    public var isDuplicateError:Bool {
        switch self {
        case .duplicateRequest: return true
        default: return false
        }
    }
}


///Generic Provider for WebService with concrete type Requests and Response
open class WebServiceProvider<RequestType: WebServiceRequesting> {
    private let service: WebService
    
    /// Default delegate for responses. Apply before call new request.
    public weak var delegate:WebServiceDelegate?
    

    /// Constructor for WebServiceProvider. Require setuped WebService.
    public init(webService:WebService, delegate:WebServiceDelegate? = nil) {
        self.service = webService
        self.delegate = delegate
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
    public func request<T>(_ request:RequestType, dataFromStorage:((_ data:T) -> Void)? = nil, completionResponse:((_ response:WebServiceProviderResponse<T>) -> Void)?) {
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
            completionResponseInternal = { completionResponse(WebServiceProviderResponse<T>.init(response: $0)) }
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
    public func requestReadStorage<T>(_ request:RequestType, completionResponse:@escaping (_ response:WebServiceProviderResponse<T>) -> Void) {
        //CompletionResponse
        let completionResponseInternal:(_ response:WebServiceResponse) -> Void = { completionResponse(WebServiceProviderResponse<T>.init(response: $0)) }
        
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
    public func request(_ request:RequestType, includeResponseStorage:Bool = false, customDelegate:WebServiceDelegate? = nil) {
        service.request(request, includeResponseStorage: includeResponseStorage, customDelegate: customDelegate ?? delegate)
    }
    
    
    /**
     Request for only storage. Response result in default or custom delegate.
     
     - Parameters:
     - request: The request data.
     - customDelegate: Optional. Unique delegate for current request.
     */
    public func requestReadStorage(_ request:RequestType, customDelegate:WebServiceDelegate? = nil) {
        service.requestReadStorage(request, customDelegate: customDelegate ?? delegate)
    }
    
}


//MARK: - Internal helpers
extension WebServiceProviderResponse {
    init(response: WebServiceResponse) {
        switch response {
        case .data(let data):
            if let data = data as? T {
                self = .data(data)
            } else {
                self = .error(WebServiceResponseError.invalidData)
            }
            
        case .error(let error):
            self = .error(error)
            
        case .canceledRequest:
            self = .canceledRequest
            
        case .duplicateRequest:
            self = .duplicateRequest
        }
    }
}
