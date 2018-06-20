//
//  WebServiceRequestProvider.swift
//  WebServiceSwift 3.0.0
//
//  Created by Короткий Виталий (ViR) on 24.04.2018.
//  Updated to 3.0.0 by Короткий Виталий (ViR) on 20.06.2018.
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
    
    
    // MARK: Perform requests and read from storage
    
    /**
     Request to server (endpoint). Response result in closure.
     
     - Parameters:
        - request: The request with data and result type.
        - completionHandler: Closure for response result from server.
     */
    public func performRequest(_ request: RequestType, completionHandler: @escaping (_ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        service.performRequest(request, completionHandler: completionHandler)
    }
    
    /**
     Request to server (endpoint). Response result in closure.
     
     - Parameters:
         - request: The request with data and result type.
         - key: unique key for controling requests - contains and canceled. Also use for excludeDuplicate.
         - excludeDuplicate: Exclude duplicate requests. Requests are equal if their keys match.
         - completionHandler: Closure for response result from server.
     */
    public func performRequest(_ request: RequestType, key: AnyHashable, excludeDuplicate: Bool, completionHandler: @escaping (_ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        service.performRequest(request, key: key, excludeDuplicate: excludeDuplicate, completionHandler: completionHandler)
    }
    
    /**
     Read last success data from storage. Response result in closure.
     
     - Parameters:
         - request: The request with data.
         - dependencyNextRequest: Type dependency from next performRequest.
         - completionHandler: Closure for read data from storage.
         - timeStamp: TimeStamp when saved from server (endpoint).
         - response: Result read from storage.
     */
    public func readStorage(_ request: RequestType, dependencyNextRequest: WebService.ReadStorageDependencyType = .notDepend, completionHandler: @escaping (_ timeStamp: Date?, _ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        service.readStorage(request, dependencyNextRequest: dependencyNextRequest, completionHandler: completionHandler)
    }
    
    
    // MARK: Perform requests use delegate for response
    
    /**
     Request to server (endpoint). Response result send to `WebServiceRequestProvider.delegate`.
     
     - Parameters:
        - request: The request with data.
     */
    public func performRequest(_ request: RequestType) {
        service.performRequest(request, responseDelegate: delegate)
    }
    
    /**
     Request to server (endpoint). Response result send to `WebServiceRequestProvider.delegate`.
     
     - Parameters:
         - request: The request with data.
         - key: unique key for controling requests - contains and canceled. Also use for excludeDuplicate.
         - excludeDuplicate: Exclude duplicate requests. Requests are equal if their keys match.
     */
    public func performRequest(_ request: RequestType, key: AnyHashable, excludeDuplicate: Bool) {
        service.performRequest(request, key: key, excludeDuplicate: excludeDuplicate, responseDelegate: delegate)
    }
    
    /**
     Read last success data from storage. Response result send to `WebServiceRequestProvider.delegate`.
     
     - Parameters:
         - request: The request with data.
         - key: unique key for controling requests, use only for response delegate.
         - dependencyNextRequest: Type dependency from next performRequest.
     */
    public func readStorage(_ request: RequestType, key: AnyHashable? = nil, dependencyNextRequest: WebService.ReadStorageDependencyType = .notDepend) {
        if let delegate = delegate {
            service.readStorage(request, key: key, dependencyNextRequest: dependencyNextRequest, responseDelegate: delegate)
        }
    }
    
    
    // MARK: Control requests
    
    /**
     Returns a Boolean value indicating whether the current queue contains requests the given type.
     
     - Returns: `true` if one request with RequestType.Type was found in the current queue; otherwise, `false`.
     */
    public func containsRequests() -> Bool {
        return service.containsRequest(requestType: RequestType.self)
    }
    
    /**
     Returns a Boolean value indicating whether the current queue contains the given request with key.
     
     - Parameter key: The key to find requests in the current queue.
     - Returns: `true` if the request with key was found in the current queue; otherwise, `false`.
     */
    public func containsRequest(key: AnyHashable) -> Bool {
        return service.containsRequest(key: key)
    }
    
    /**
     Returns a Boolean value indicating whether the current queue contains requests the given type key.
     
     - Parameter keyType: The type requestKey to find in the all current queue.
     - Returns: `true` if one request with key.Type was found in the current queue; otherwise, `false`.
     */
    public func containsRequest<T: Hashable>(keyType: T.Type) -> Bool {
        return service.containsRequest(keyType: keyType)
    }
    
    /// Cancel all requests for request type. The RequestType.Type to find in the current queue.
    public func cancelRequests() {
        service.cancelRequests(requestType: RequestType.self)
    }
    
    /**
     Cancel all requests with key.
     
     - Parameter key: The key to find in the current queue.
     */
    public func cancelRequests(key: AnyHashable) {
        service.cancelRequests(key: key)
    }
    
    /**
     Cancel all requests with key.Type.
     
     - Parameter keyType: The key.Type to find in the current queue.
     */
    public func cancelRequests<T: Hashable>(keyType: T.Type) {
        service.cancelRequests(keyType: keyType)
    }
}

//MARK: Support Hashable requests
extension WebServiceRequestProvider where RequestType: Hashable {
    
    /**
     Request to server (endpoint). Response result in closure.
     
     - Parameters:
         - request: The hashable (also equatable) request with data and result type.
         - excludeDuplicate: Exclude duplicate equatable requests.
         - completionHandler: Closure for response result from server.
     */
    public func performRequest(_ request: RequestType, excludeDuplicate: Bool, completionHandler: @escaping (_ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        service.performRequest(request, excludeDuplicate: excludeDuplicate, completionHandler: completionHandler)
    }
    
    /**
     Request to server (endpoint). Response result send to `WebServiceRequestProvider.delegate`.
     
     - Parameters:
         - request: The hashable (also equatable) request with data.
         - excludeDuplicate: Exclude duplicate equatable requests.
     */
    public func performRequest(_ request: RequestType, excludeDuplicate: Bool) {
        service.performRequest(request, excludeDuplicate: excludeDuplicate, responseDelegate: delegate)
    }
    
    
    /**
     Returns a Boolean value indicating whether the current queue contains the given request.
     
     - Parameter request: The request to find in the current queue.
     - Returns: `true` if the request was found in the current queue; otherwise, `false`.
     */
    public func containsRequest(request: RequestType) -> Bool {
        return service.containsRequest(request: request)
    }
    
    /**
     Cancel all requests with equal this request.
     
     - Parameter request: The request to find in the current queue.
     */
    public func cancelRequests(request: RequestType) {
        service.cancelRequests(request: request)
    }
}

