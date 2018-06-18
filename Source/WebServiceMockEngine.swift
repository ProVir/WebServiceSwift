//
//  WebServiceMockEngine.swift
//  WebServiceSwift 2.3.0
//
//  Created by ViR (Короткий Виталий) on 12.03.2018.
//  Updated to 2.3.0 by ViR (Короткий Виталий) on 25.05.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation


//MARK: Mock Request

/// Base protocol for request with support mock data
public protocol WebServiceMockBaseRequesting {
    /// Fast switch enable/disable mock data (if `WebServiceMockEngine` as first in array `WebService.engines`).
    var isSupportedRequest: Bool { get }
    
    /// After timeout mock data send as response. `nil` - without pause.
    var timeWait: TimeInterval? { get }
    
    /// Identifier for dictionary helpers, `nil` - don't use helper. Helpers are created once and when used within one instance of the engine.
    var helperIdentifier: String? { get }
    
    /// Create a helper if it was not created earlier. `nil` - don't use helper
    func createHelper() -> Any?
    
    /// Mock data without generic information as response.
    func responseBaseHandler(helper: Any?) throws -> Any?
}

/// Protocol for request with support mock data
public protocol WebServiceMockRequesting: WebServiceRequesting, WebServiceMockBaseRequesting {
    /// Mock data as response. Require implementation.
    func responseHandler(helper: Any?) throws -> ResultType
}

public extension WebServiceMockRequesting {
    public func responseBaseHandler(helper: Any?) throws -> Any? {
        return try responseHandler(helper: helper)
    }
}



//MARK: Mock Engine
/// Simple engine for temporary mock requests.
open class WebServiceMockEngine: WebServiceEngining {
    
    /// Item for store current requests in process
    struct RequestItem {
        var workItem: DispatchWorkItem
        var canceled: () -> Void
    }
    
    public let queueForRequest: DispatchQueue? = nil
    public let queueForDataHandler: DispatchQueue? = nil
    public let queueForDataHandlerFromStorage: DispatchQueue? = nil
    public let useNetworkActivityIndicator = false
    
    var helpersArray: [String: Any] = [:]
    var requests: [UInt64: RequestItem] = [:]
    
    public var rawDataFromStoreAlwaysNil: Bool
    public var alwaysSupported: Bool
    
    
    /// Need override to support custom requests (not WebServiceMockBaseRequesting)
    open func isSupportedRequest(_ request: WebServiceBaseRequesting) -> Bool {
        if let request = request as? WebServiceMockBaseRequesting {
            return alwaysSupported || request.isSupportedRequest
        } else {
            return false
        }
    }
    
    /// Need override to support custom requests (not WebServiceMockBaseRequesting)
    open func convertToMockRequest(_ request: WebServiceBaseRequesting) -> WebServiceMockBaseRequesting? {
        return request as? WebServiceMockBaseRequesting
    }
    
    /**
     Mock engine constructor.
 
     - Parameters:
        - rawDataFromStoreAlwaysNil: If `true` - all read raw data from storage return as nil for supporteds requests. Default: true.
        - alwaysSupported: if `true` - support all mock request and ignore `isSupportedRequest` parameter (always true). Usually use for unit tests. Default: false.
     */
    public init(rawDataFromStoreAlwaysNil: Bool = true, alwaysSupported: Bool = false) {
        self.rawDataFromStoreAlwaysNil = rawDataFromStoreAlwaysNil
        self.alwaysSupported = alwaysSupported
    }
    
    public func isSupportedRequest(_ request: WebServiceBaseRequesting, rawDataTypeForRestoreFromStorage: Any.Type?) -> Bool {
        // Support raw data from storage if response from storage always nil.
        if rawDataTypeForRestoreFromStorage != nil && !rawDataFromStoreAlwaysNil { return false }
        
        // Support only WebServiceMockRequesting with enable support.
        return isSupportedRequest(request)
    }
    
    public func performRequest(requestId: UInt64, request: WebServiceBaseRequesting, completionWithData: @escaping (Any) -> Void, completionWithError: @escaping (Error) -> Void, canceled: @escaping () -> Void) {
        guard let request = convertToMockRequest(request) else {
            completionWithError(WebServiceRequestError.notSupportRequest)
            return
        }
        
        //Helper Object
        let helper:Any?
        if let identifier = request.helperIdentifier {
            if let obj = helpersArray[identifier] {
                helper = obj
            } else if let obj = request.createHelper() {
                helpersArray[identifier] = obj
                helper = obj
            } else {
                helper = nil
            }
        } else {
            helper = nil
        }
        
        //Request
        let workItem =  DispatchWorkItem { [weak self] in
            self?.requests.removeValue(forKey: requestId)
            
            do {
                let data = try request.responseBaseHandler(helper: helper) ?? Void()
                completionWithData(data)
            } catch {
                completionWithError(error)
            }
        }
        
        //Run request with pause time
        requests[requestId] = RequestItem(workItem: workItem, canceled: canceled)
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + (request.timeWait ?? 0), execute: workItem)
    }
    
    public func cancelRequest(requestId: UInt64) {
        if let requestItem = requests.removeValue(forKey: requestId) {
            requestItem.workItem.cancel()
            requestItem.canceled()
        }
    }
    
    public func dataHandler(request: WebServiceBaseRequesting, data: Any, isRawFromStorage: Bool) throws -> Any? {
        if isRawFromStorage { return nil }
        else if data is Void { return nil }
        else { return data }
    }
}
