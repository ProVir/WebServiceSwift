//
//  RequestProvider.swift
//  WebServiceSwift 4.0.0
//
//  Created by Короткий Виталий (ViR) on 24.04.2018.
//  Updated to 3.0.0 by Короткий Виталий (ViR) on 04.09.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation

/// Provider for single request type.
public class WebServiceRequestProvider<RequestType: WebServiceRequesting>: WebServiceProvider {
    fileprivate let service: WebService
    
    public required init(webService: WebService) {
        self.service = webService
    }
    
    /// Default excludeDuplicate for hashable requests.
    private var internalExcludeDuplicateDefault: Bool = false
    
    // MARK: Perform requests and read from storage
    
    /**
     Request to server (gateway). Response result in closure.
     
     - Parameters:
        - request: The request with data and result type.
        - completionHandler: Closure for response result from server.
     */
    public func performRequest(_ request: RequestType, completionHandler: @escaping (_ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        service.performBaseRequest(request, key: nil, excludeDuplicate: internalExcludeDuplicateDefault, completionHandler: { completionHandler( $0.convert() ) })
    }
    
    /**
     Request to server (gateway). Response result in closure.
     
     - Parameters:
         - request: The request with data and result type.
         - key: Unique key for controling requests - contains and canceled. Also use for excludeDuplicate.
         - excludeDuplicate: Exclude duplicate requests. Requests are equal if their keys match.
         - completionHandler: Closure for response result from server.
     */
    public func performRequest(_ request: RequestType, key: AnyHashable, excludeDuplicate: Bool, completionHandler: @escaping (_ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        service.performBaseRequest(request, key: key, excludeDuplicate: excludeDuplicate, completionHandler: { completionHandler( $0.convert() ) })
    }
    
    // MARK: Contains requests
    
    /**
     Returns a Boolean value indicating whether the current queue contains requests the given type.
     
     - Returns: `true` if one request with RequestType.Type was found in the current queue; otherwise, `false`.
     */
    public func containsRequests() -> Bool {
        return service.containsRequest(type: RequestType.self)
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
    public func containsRequest<K: Hashable>(keyType: K.Type) -> Bool {
        return service.containsRequest(keyType: keyType)
    }
    
    // MARK: Cancel requests
    
    /// Cancel all requests for request type. The RequestType.Type to find in the current queue.
    public func cancelRequests() {
        service.cancelRequests(type: RequestType.self)
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
    public func cancelRequests<K: Hashable>(keyType: K.Type) {
        service.cancelRequests(keyType: keyType)
    }
}

// MARK: Support Hashable requests
extension WebServiceRequestProvider where RequestType: Hashable {

    /// Default excludeDuplicate for hashable requests.
    public var excludeDuplicateDefault: Bool {
        get { return internalExcludeDuplicateDefault }
        set { internalExcludeDuplicateDefault = newValue }
    }

    /**
     Request to server (gateway). Response result in closure.
     
     - Parameters:
         - request: The hashable (also equatable) request with data and result type.
         - excludeDuplicate: Exclude duplicate equatable requests.
         - completionHandler: Closure for response result from server.
     */
    public func performRequest(_ request: RequestType, excludeDuplicate: Bool, completionHandler: @escaping (_ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        service.performBaseRequest(request, key: nil, excludeDuplicate: excludeDuplicate, completionHandler: { completionHandler( $0.convert() ) })
    }
    
    /**
     Returns a Boolean value indicating whether the current queue contains the given request.
     
     - Parameter request: The request to find in the current queue.
     - Returns: `true` if the request was found in the current queue; otherwise, `false`.
     */
    public func containsRequest(_ request: RequestType) -> Bool {
        return service.containsRequest(request)
    }
    
    /**
     Cancel all requests with equal this request.
     
     - Parameter request: The request to find in the current queue.
     */
    public func cancelRequests(_ request: RequestType) {
        service.cancelRequests(request)
    }
}

// MARK: Support Empty requests
extension WebServiceRequestProvider where RequestType: WebServiceEmptyRequesting {
    
    /**
     Request to server (gateway). Response result in closure.
     
     - Parameters:
        - completionHandler: Closure for response result from server.
     */
    public func performRequest(completionHandler: @escaping (_ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        service.performBaseRequest(RequestType.init(), key: nil, excludeDuplicate: internalExcludeDuplicateDefault) {
            completionHandler($0.convert())
        }
    }
}

// MARK: Support Storages
extension WebServiceRequestProvider where RequestType: WebServiceRequestBaseStoring {
    /**
     Read last success data from storage. Response result in closure.

     - Parameters:
     - request: The request with data.
     - dependencyNextRequest: Type dependency from next performRequest.
     - completionHandler: Closure for read data from storage.
     - timeStamp: TimeStamp when saved from server (gateway).
     - response: Result read from storage.
     */
    public func readStorage(_ request: RequestType, dependencyNextRequest: WebService.ReadStorageDependencyType = .notDepend, completionHandler: @escaping (_ timeStamp: Date?, _ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        service.readStorage(request, dependencyNextRequest: dependencyNextRequest, completionHandler: completionHandler)
    }

    /**
     Delete data in storage for concrete request.

     - Parameter request: Original request.
     */
    public func deleteInStorage(request: RequestType) {
        service.deleteInStorage(request: request)
    }
}

extension WebServiceRequestProvider where RequestType: WebServiceRequestBaseStoring, RequestType: WebServiceEmptyRequesting {
    /**
     Read last success data from storage. Response result in closure.

     - Parameters:
     - dependencyNextRequest: Type dependency from next performRequest.
     - completionHandler: Closure for read data from storage.
     - timeStamp: TimeStamp when saved from server (gateway).
     - response: Result read from storage.
     */
    public func readStorage(dependencyNextRequest: WebService.ReadStorageDependencyType = .notDepend, completionHandler: @escaping (_ timeStamp: Date?, _ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        service.readStorage(RequestType.init(), dependencyNextRequest: dependencyNextRequest, completionHandler: completionHandler)
    }
}
