//
//  WebServiceGroupProvider.swift
//  WebServiceSwift 3.0.0
//
//  Created by Короткий Виталий (ViR) on 22.06.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation

/// Provider for group requests
public class WebServiceGroupProvider<GroupType: WebServiceGroupRequests>: WebServiceRestrictedProvider, WebServiceProvider {
    public required init(webService: WebService) {
        super.init(webService: webService, requestTypes: GroupType.requestTypes)
    }
}


/// Equal WebService functional, but support only concrete request types (assert if don't support)
public class WebServiceRestrictedProvider {
    private let service: WebService
    private let requestTypes: [WebServiceBaseRequesting.Type]
    private let requestTypesAsKeys: Set<String>
    
    /// Constructor with filter request types.
    public init(webService: WebService, requestTypes: [WebServiceBaseRequesting.Type]) {
        self.service = webService
        self.requestTypes = requestTypes
        self.requestTypesAsKeys = Set(requestTypes.map { "\($0)" })
    }
    
    // Response delegate for responses. Apply before call new request.
    public weak var delegate: WebServiceDelegate?
    
    
    /// MARK: Test request for support
    public func canUseRequest(type requestType: WebServiceBaseRequesting.Type) -> Bool {
        return requestTypesAsKeys.contains("\(requestType)")
    }
    
    func testRequest(type requestType: WebServiceBaseRequesting.Type, file: StaticString = #file, line: UInt = #line) -> Bool {
        if canUseRequest(type: requestType) { return true }
        
        assertionFailure("Request type don't support in this provider", file: file, line: line)
        return false
    }
    
    
    // MARK: Perform requests
    
    /**
     Request to server (endpoint). Response result in closure.
     
     - Parameters:
         - request: The request with data and result type.
         - completionHandler: Closure for response result from server.
     */
    public func performRequest<RequestType: WebServiceRequesting>(_ request: RequestType, completionHandler: @escaping (_ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        guard testRequest(type: RequestType.self) else { return }
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
    public func performRequest<RequestType: WebServiceRequesting>(_ request: RequestType, key: AnyHashable, excludeDuplicate: Bool, completionHandler: @escaping (_ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        guard testRequest(type: RequestType.self) else { return }
        service.performRequest(request, key: key, excludeDuplicate: excludeDuplicate, completionHandler: completionHandler)
    }
    
    /**
     Request to server (endpoint). Response result in closure.
     
     - Parameters:
         - request: The hashable (also equatable) request with data and result type.
         - excludeDuplicate: Exclude duplicate equatable requests.
         - completionHandler: Closure for response result from server.
     */
    public func performRequest<RequestType: WebServiceRequesting & Hashable>(_ request: RequestType, excludeDuplicate: Bool, completionHandler: @escaping (_ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        guard testRequest(type: RequestType.self) else { return }
        service.performRequest(request, excludeDuplicate: excludeDuplicate, completionHandler: completionHandler)
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
    public func readStorage<RequestType: WebServiceRequesting>(_ request: RequestType, dependencyNextRequest: WebService.ReadStorageDependencyType = .notDepend, completionHandler: @escaping (_ timeStamp: Date?, _ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        guard testRequest(type: RequestType.self) else { return }
        service.readStorage(request, dependencyNextRequest: dependencyNextRequest, completionHandler: completionHandler)
    }
    
    
    // MARK: Perform requests use delegate for response
    
    /**
     Request to server (endpoint). Response result send to delegate.
     
     - Parameter request: The request with data.
     */
    public func performRequest(_ request: WebServiceBaseRequesting) {
        guard testRequest(type: type(of: request)) else { return }
        service.performRequest(request, responseDelegate: delegate)
    }
    
    /**
     Request to server (endpoint). Response result send to delegate.
     
     - Parameters:
         - request: The request with data.
         - key: unique key for controling requests - contains and canceled. Also use for excludeDuplicate.
         - excludeDuplicate: Exclude duplicate requests. Requests are equal if their keys match.
     */
    public func performRequest(_ request: WebServiceBaseRequesting, key: AnyHashable, excludeDuplicate: Bool) {
        guard testRequest(type: type(of: request)) else { return }
        service.performRequest(request, key: key, excludeDuplicate: excludeDuplicate, responseDelegate: delegate)
    }
    
    /**
     Request to server (endpoint). Response result send to delegate.
     
     - Parameters:
         - request: The hashable (also equatable) request with data.
         - excludeDuplicate: Exclude duplicate equatable requests.
     */
    public func performRequest<RequestType: WebServiceBaseRequesting & Hashable>(_ request: RequestType, excludeDuplicate: Bool) {
        guard testRequest(type: RequestType.self) else { return }
        service.performRequest(request, excludeDuplicate: excludeDuplicate, responseDelegate: delegate)
    }
    
    /**
     Read last success data from storage. Response result send to delegate.
     
     - Parameters:
         - request: The request with data.
         - key: unique key for controling requests, use only for response delegate.
         - dependencyNextRequest: Type dependency from next performRequest.
     */
    public func readStorage(_ request: WebServiceBaseRequesting, key: AnyHashable? = nil, dependencyNextRequest: WebService.ReadStorageDependencyType = .notDepend) {
        guard testRequest(type: type(of: request)) else { return }
        if let delegate = delegate {
            service.readStorage(request, key: key, dependencyNextRequest: dependencyNextRequest, responseDelegate: delegate)
        }
    }
    
    // MARK: Contains requests
    
    /**
     Returns a Boolean value indicating whether the current queue contains support requests.
     
     - Returns: `true` if one request from requestTypes was found in the current queue; otherwise, `false`.
     */
    public func containsSupportRequests() -> Bool {
        for requestType in requestTypes {
            if service.containsRequest(type: requestType) { return true }
        }
        
        return false
    }
    
    /**
     Returns a Boolean value indicating whether the current queue contains the given request.
     
     - Parameter request: The request to find in the current queue.
     - Returns: `true` if the request was found in the current queue; otherwise, `false`.
     */
    public func containsRequest<RequestType: WebServiceBaseRequesting & Hashable>(_ request: RequestType) -> Bool {
        guard testRequest(type: RequestType.self) else { return false }
        return service.containsRequest(request)
    }
    
    /**
     Returns a Boolean value indicating whether the current queue contains requests the given type.
     
     - Parameter requestType: The type request to find in the all current queue.
     - Returns: `true` if one request with WebServiceBaseRequesting.Type was found in the current queue; otherwise, `false`.
     */
    public func containsRequest(type requestType: WebServiceBaseRequesting.Type) -> Bool {
        guard testRequest(type: requestType) else { return false }
        return service.containsRequest(type: requestType)
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
    
    
    //MARK: Cancel requests
    
    /// Cancel all support requests from requestTypes.
    public func cancelAllSupportRequests() {
        for requestType in requestTypes {
            service.cancelRequests(type: requestType)
        }
    }
    
    /**
     Cancel all requests with equal this request.
     
     - Parameter request: The request to find in the current queue.
     */
    public func cancelRequests<RequestType: WebServiceBaseRequesting & Hashable>(_ request: RequestType) {
        guard testRequest(type: RequestType.self) else { return }
        service.cancelRequests(request)
    }
    
    /**
     Cancel all requests for request type.
     
     - Parameter requestType: The WebServiceBaseRequesting.Type to find in the current queue.
     */
    public func cancelRequests(type requestType: WebServiceBaseRequesting.Type) {
        guard testRequest(type: requestType) else { return }
        service.cancelRequests(type: requestType)
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
