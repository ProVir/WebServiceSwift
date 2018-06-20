//
//  WebServiceMockRequestEndpoint.swift
//  WebServiceSwift 3.0.0
//
//  Created by Короткий Виталий (ViR) on 19.06.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation



public class WebServiceMockRequestEndpoint<RequestType: WebServiceRequesting>: WebServiceEndpoint {
    public let queueForRequest: DispatchQueue? = nil
    public let queueForDataHandler: DispatchQueue? = nil
    public let queueForDataHandlerFromStorage: DispatchQueue? = nil
    public let useNetworkActivityIndicator = false
    
    public let mockHandler: (RequestType) throws -> RequestType.ResultType
    public var timeWait: TimeInterval?
    public var rawDataFromStoreAlwaysNil: Bool = true
    
    private var requests: [UInt64: DispatchWorkItem] = [:]
    
    
    public init(timeWait: TimeInterval? = nil, mockHandler: @escaping (RequestType) throws -> RequestType.ResultType) {
        self.mockHandler = mockHandler
        self.timeWait = timeWait
    }
    
    
    public func isSupportedRequest(_ request: WebServiceBaseRequesting, rawDataTypeForRestoreFromStorage: Any.Type?) -> Bool {
        // Support raw data from storage if response from storage always nil.
        if rawDataTypeForRestoreFromStorage != nil && !rawDataFromStoreAlwaysNil { return false }
        
        // Support only WebServiceMockRequesting with enable support.
        return request is RequestType
    }
    
    public func performRequest(requestId: UInt64, request: WebServiceBaseRequesting, completionWithRawData: @escaping (Any) -> Void, completionWithError: @escaping (Error) -> Void) {
        guard let request = request as? RequestType else {
            completionWithError(WebServiceRequestError.notSupportRequest)
            return
        }
        
        //Request
        let handler = mockHandler
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.requests.removeValue(forKey: requestId)
            
            do {
                let data = try handler(request)
                completionWithRawData(data)
            } catch {
                completionWithError(error)
            }
        }
        
        //Run request with pause time
        requests[requestId] = workItem
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + (timeWait ?? 0), execute: workItem)
    }
    
    public func canceledRequest(requestId: UInt64) {
        if let workItem = requests.removeValue(forKey: requestId) {
            workItem.cancel()
        }
    }
    
    public func dataProcessing(request: WebServiceBaseRequesting, rawData: Any, fromStorage: Bool) throws -> Any? {
        if fromStorage { return nil }
        else { return rawData }
    }
    
}
