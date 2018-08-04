//
//  WebServiceAlamofireSimpleEndpoint.swift
//  WebServiceSwift 3.0.0
//
//  Created by Короткий Виталий (ViR) on 01.06.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation
import Alamofire


//MARK: Request

/// Base protocol for request use WebServiceAlamofireSimpleEndpoint
public protocol WebServiceAlamofireBaseRequesting {
    /// Create alamofire request with use session manager.
    func afRequest(sessionManager: Alamofire.SessionManager) throws -> Alamofire.DataRequest

    /// Response type (binary or json) for decode response.
    var afResponseType: WebServiceAlamofireResponseType { get }
    
    /// Decode response to value. Used `data.binary` or `data.json` dependency from `afResponseType` parameter. Perofrm in background thread.
    func afBaseDecodeResponse(_ data: WebServiceAlamofireResponseData) throws -> Any
}

public protocol WebServiceAlamofireRequesting: WebServiceAlamofireBaseRequesting, WebServiceRequesting {
    /// Decode response to value. Used `data.binary` or `data.json` dependency from `afResponseType` parameter. Perofrm in background thread.
    func afDecodeResponse(_ data: WebServiceAlamofireResponseData) throws -> ResultType
}

public extension WebServiceAlamofireRequesting {
    func afBaseDecodeResponse(_ data: WebServiceAlamofireResponseData) throws -> Any {
        return try afDecodeResponse(data)
    }
}

//MARK: Response
/// Response type to require for decoder
public enum WebServiceAlamofireResponseType {
    case binary
    case json
}

/// Response data for decoder
public enum WebServiceAlamofireResponseData {
    case binary(Data)
    case json(Any)
    
    /// Get binary data for decoder
    public var binary: Data {
        if case let .binary(value) = self { return value }
        else { fatalError("Not binary data") }
    }
    
    /// Get json data for decoder
    public var json: Any {
        if case let .json(value) = self { return value }
        else { fatalError("Not json data") }
    }
}

//MARK: Auto decoders
/// Protocol for enable auto implementation response decoder (afResponseType and afDecodeResponse) for certain result types.
protocol WebServiceAlamofireAutoDecoder: WebServiceRequesting { }

/// Support AutoDecoder for request, when ignored result data from server (ResultType = Void).
extension WebServiceAlamofireAutoDecoder where ResultType == Void {
    var afResponseType: WebServiceAlamofireResponseType { return .binary }
    func afDecodeResponse(_ data: WebServiceAlamofireResponseData) throws -> Void {
        return Void()
    }
}

/// Support AutoDecoder for binary reslt type (ResultType = Data)
extension WebServiceAlamofireAutoDecoder where ResultType == Data {
    var afResponseType: WebServiceAlamofireResponseType { return .binary }
    func afDecodeResponse(_ data: WebServiceAlamofireResponseData) throws -> Data {
        return data.binary
    }
}


//MARK: Endpoint
/// Simple HTTP Endpoint (use Alamofire)
public class WebServiceAlamofireSimpleEndpoint: WebServiceAlamofireBaseEndpoint {
    private let sessionManager: Alamofire.SessionManager
    
    /**
     Simple HTTP Endpoint used Alamofire constructor.
     
     - Parameters:
         - sessionManager: Alamofire.SessionManager for use, default Alamofire.SessionManager.default.
         - queueForRequest: Thread Dispatch Queue for `perofrmRequest()` and `cancelRequests()` methods.
         - useNetworkActivityIndicator: When `true`, showed networkActivityIndicator in statusBar when requests in process.
     */
    public init(sessionManager: Alamofire.SessionManager = Alamofire.SessionManager.default, queueForRequest: DispatchQueue? = nil, useNetworkActivityIndicator: Bool = true) {
        self.sessionManager = sessionManager
        super.init(queueForRequest: queueForRequest, useNetworkActivityIndicator: useNetworkActivityIndicator)
    }
    
    
    //MARK: Endpoint implementation
    public override func isSupportedRequest(_ request: WebServiceBaseRequesting, rawDataTypeForRestoreFromStorage: Any.Type?) -> Bool {
        return request is WebServiceAlamofireBaseRequesting
    }
    
    public override func performRequest(requestId: UInt64, data: RequestData) throws -> DataRequest? {
        guard let request = data.request as? WebServiceAlamofireBaseRequesting else {
            throw WebServiceRequestError.notSupportRequest
        }
        
        return try request.afRequest(sessionManager: sessionManager)
    }
    
    public override func responseAlamofire(_ response: DataResponse<Data>, requestId: UInt64, requestData: RequestData) throws -> Any {
        switch response.result {
        case .success(let data):
            //Validation data for http status code
            if let statusCode = response.response?.statusCode, statusCode >= 300 {
                throw WebServiceResponseError.httpStatusCode(statusCode)
            }
            
            return data
            
        case .failure(let error):
            throw error
        }
    }
    
    public override func dataProcessing(request: WebServiceBaseRequesting, rawData: Any, fromStorage: Bool) throws -> Any {
        guard let binary = rawData as? Data, let request = request as? WebServiceAlamofireBaseRequesting else {
            throw WebServiceRequestError.notSupportDataProcessing
        }
        
        switch request.afResponseType {
        case .binary:
            return try request.afBaseDecodeResponse(WebServiceAlamofireResponseData.binary(binary))
            
        case .json:
            let jsonData = try JSONSerialization.jsonObject(with: binary, options: [])
            return try request.afBaseDecodeResponse(WebServiceAlamofireResponseData.json(jsonData))
        }
    }
    
}
