//
//  WebServiceMockRequestGateway.swift
//  WebServiceSwift 4.0.0
//
//  Created by Короткий Виталий (ViR) on 19.06.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation

/// Simple gateway for unit mock requests with responseHandler in gateway.
public class WebServiceMockRequestGateway<RequestType: WebServiceRequesting>: WebServiceGateway {
    public let queueForRequest: DispatchQueue? = nil
    public let queueForDataProcessing: DispatchQueue? = nil
    public let queueForDataProcessingFromStorage: DispatchQueue? = nil
    public let useNetworkActivityIndicator = false
    
    public let mockHandler: (RequestType) throws -> RequestType.ResultType
    
    /// After timeout mock data send as response. `nil` - without pause.
    public var timeDelay: TimeInterval?
    
    /// If `true` - all read raw data from storage return as nil for supporteds requests. Default: true.
    public var rawDataFromStoreAlwaysNil: Bool = true
    

    /**
     Mock gateway constructor.
     
     - Parameters:
        - timeDelay: After timeout mock data send as response. `nil` - without pause.
        - mockHandler: responseHandler for requests.
     */
    public init(timeDelay: TimeInterval? = nil, mockHandler: @escaping (RequestType) throws -> RequestType.ResultType) {
        self.mockHandler = mockHandler
        self.timeDelay = timeDelay
    }
    
    
    // MARK: Gateway implementation
    private var requests: [UInt64: DispatchWorkItem] = [:]
    
    public func isSupportedRequest(_ request: WebServiceBaseRequesting, rawDataTypeForRestoreFromStorage: WebServiceRawData.Type?) -> Bool {
        // Support raw data from storage if response from storage always nil.
        if rawDataTypeForRestoreFromStorage != nil && !rawDataFromStoreAlwaysNil { return false }
        
        // Support only WebServiceMockRequesting with enable support.
        return request is RequestType
    }
    
    public func performRequest(requestId: UInt64, request: WebServiceBaseRequesting, completion: @escaping (Result<WebServiceRawData, Error>) -> Void) {
        guard let request = request as? RequestType else {
            completion(.failure(WebServiceRequestError.notSupportRequest))
            return
        }
        
        //Request
        let handler = mockHandler
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.requests.removeValue(forKey: requestId)
            completion(Result { RawData(result: try handler(request)) })
        }
        
        //Run request with pause time
        requests[requestId] = workItem
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + (timeDelay ?? 0), execute: workItem)
    }
    
    public func canceledRequest(requestId: UInt64) {
        if let workItem = requests.removeValue(forKey: requestId) {
            workItem.cancel()
        }
    }
    
    public func dataProcessing(request: WebServiceBaseRequesting, rawData: WebServiceRawData, fromStorage: Bool) throws -> Any {
        guard fromStorage == false, let result = (rawData as? RawData)?.result else {
            throw WebServiceRequestError.notSupportDataProcessing
        }

        return result
    }

    private struct RawData: WebServiceRawData {
        let result: Any
        let storableRawBinary: Data? = nil
    }
}
