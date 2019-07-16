//
//  WebServiceMockGateway.swift
//  WebServiceSwift 4.0.0
//
//  Created by Короткий Виталий (ViR) on 12.03.2018.
//  Updated to 3.0.0 by Короткий Виталий (ViR) on 04.09.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation


// MARK: Mock Request
/// Helper for mocks
public protocol WebServiceMockHelper { }

/// Base protocol for request with support mock data
public protocol WebServiceMockBaseRequesting {
    /// Fast switch enable/disable mock data (if `WebServiceMockGateway` as first in array `WebService.gateways`).
    var isSupportedRequestForMock: Bool { get }
    
    /// After timeout mock data send as response. `nil` - without pause.
    var mockTimeDelay: TimeInterval? { get }
    
    /// Identifier for dictionary helpers, `nil` - don't use helper. Helpers are created once and when used within one instance of the gateway.
    var mockHelperIdentifier: String? { get }
    
    /// Create a helper if it was not created earlier. `nil` - don't use helper
    func mockCreateHelper() -> WebServiceMockHelper?
    
    /// Mock data without generic information as response.
    func mockResponseBaseHandler(helper: WebServiceMockHelper?) throws -> Any
}

/// Protocol for request with support mock data
public protocol WebServiceMockRequesting: WebServiceRequesting, WebServiceMockBaseRequesting {
    /// Mock data as response. Require implementation.
    func mockResponseHandler(helper: WebServiceMockHelper?) throws -> ResultType
}

public extension WebServiceMockRequesting {
    func mockResponseBaseHandler(helper: WebServiceMockHelper?) throws -> Any {
        return try mockResponseHandler(helper: helper)
    }
}

// MARK: Mock Gateway
/// Simple gateway for temporary mock requests.
open class WebServiceMockGateway: WebServiceGateway {
    public let queueForRequest: DispatchQueue? = nil
    public let queueForDataProcessingFromStorage: DispatchQueue? = nil
    public let useNetworkActivityIndicator = false
    
    public var rawDataFromStoreAlwaysNil: Bool
    public var alwaysSupported: Bool
    
    /// Need override to support custom requests (not WebServiceMockBaseRequesting)
    open func isSupportedRequest(_ request: WebServiceBaseRequesting) -> Bool {
        if let request = request as? WebServiceMockBaseRequesting {
            return alwaysSupported || request.isSupportedRequestForMock
        } else {
            return false
        }
    }
    
    /// Need override to support custom requests (not WebServiceMockBaseRequesting)
    open func convertToMockRequest(_ request: WebServiceBaseRequesting) -> WebServiceMockBaseRequesting? {
        return request as? WebServiceMockBaseRequesting
    }
    
    /**
     Mock gateway constructor.
 
     - Parameters:
        - rawDataFromStoreAlwaysNil: If `true` - all read raw data from storage return as nil for supporteds requests. Default: true.
        - alwaysSupported: if `true` - support all mock request and ignore `isSupportedRequest` parameter (always true). Usually use for unit tests. Default: false.
     */
    public init(rawDataFromStoreAlwaysNil: Bool = true, alwaysSupported: Bool = false) {
        self.rawDataFromStoreAlwaysNil = rawDataFromStoreAlwaysNil
        self.alwaysSupported = alwaysSupported
    }
    
    // MARK: Gateway implementation
    private var helpersArray: [String: WebServiceMockHelper] = [:]
    private var requests: [UInt64: DispatchWorkItem] = [:]
    
    public func isSupportedRequest(_ request: WebServiceBaseRequesting, forDataProcessingFromStorage rawDataType: WebServiceStorageRawData.Type?) -> Bool {
        // Support raw data from storage if response from storage always nil.
        if rawDataType != nil && !rawDataFromStoreAlwaysNil { return false }
        
        // Support only WebServiceMockRequesting with enable support.
        return isSupportedRequest(request)
    }
    
    public func performRequest(requestId: UInt64, request: WebServiceBaseRequesting, completion: @escaping (Result<WebServiceGatewayResponse, Error>) -> Void) {
        guard let request = convertToMockRequest(request) else {
            completion(.failure(WebServiceRequestError.notSupportRequest))
            return
        }
        
        //Helper Object
        let helper: WebServiceMockHelper?
        if let identifier = request.mockHelperIdentifier {
            if let obj = helpersArray[identifier] {
                helper = obj
            } else if let obj = request.mockCreateHelper() {
                helpersArray[identifier] = obj
                helper = obj
            } else {
                helper = nil
            }
        } else {
            helper = nil
        }
        
        //Request
        let workItem = DispatchWorkItem { [weak self] in
            self?.requests.removeValue(forKey: requestId)
            completion(Result {
                .init(
                    result: try request.mockResponseBaseHandler(helper: helper),
                    rawDataForStorage: nil
                )
            })
        }
        
        //Run request with pause time
        requests[requestId] = workItem
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + (request.mockTimeDelay ?? 0), execute: workItem)
    }
    
    public func canceledRequest(requestId: UInt64) {
        if let workItem = requests.removeValue(forKey: requestId) {
            workItem.cancel()
        }
    }
    
    public func dataProcessingFromStorage(request: WebServiceBaseRequesting, rawData: WebServiceStorageRawData) throws -> Any {
        throw WebServiceRequestError.notSupportDataProcessing
    }
}
