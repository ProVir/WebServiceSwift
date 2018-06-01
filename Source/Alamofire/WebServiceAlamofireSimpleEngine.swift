//
//  WebServiceAlamofireSimpleEngine.swift
//  WebServiceSwift 2.3.0
//
//  Created by ViR (Короткий Виталий) on 01.06.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation
import Alamofire


//MARK: Request
public protocol WebServiceAlamofireBaseRequesting {
    func afRequest(sessionManager: Alamofire.SessionManager) throws -> Alamofire.DataRequest

    var afResponseType: WebServiceAlamofireResponseType { get }
    func afBaseDecodeResponse(_ data: WebServiceAlamofireResponseData) throws -> Any?
}

public protocol WebServiceAlamofireRequesting: WebServiceAlamofireBaseRequesting, WebServiceRequesting {
    func afDecodeResponse(_ data: WebServiceAlamofireResponseData) throws -> ResultType
}

public extension WebServiceAlamofireRequesting {
    func afBaseDecodeResponse(_ data: WebServiceAlamofireResponseData) throws -> Any? {
        return try afDecodeResponse(data)
    }
}

//MARK: Response
public enum WebServiceAlamofireResponseType {
    case binary
    case json
}

public struct WebServiceAlamofireResponseData {
    //Only one is not null
    public let binary: Data!
    public let json: Any!
    
    public init(binary: Data) {
        self.binary = binary
        self.json = nil
    }
    
    public init(json: Any) {
        self.json = json
        self.binary = nil
    }
}

//MARK: Auto decoders
protocol WebServiceAlamofireAutoDecoder: WebServiceRequesting { }

extension WebServiceAlamofireAutoDecoder where ResultType == Void {
    var afResponseType: WebServiceAlamofireResponseType { return .binary }
    func afDecodeResponse(_ data: WebServiceAlamofireResponseData) throws -> Void {
        return Void()
    }
}

extension WebServiceAlamofireAutoDecoder where ResultType == Data {
    var afResponseType: WebServiceAlamofireResponseType { return .binary }
    func afDecodeResponse(_ data: WebServiceAlamofireResponseData) throws -> Data {
        return data.binary
    }
}


//MARK: Engine
public class WebServiceAlamofireSimpleEngine: WebServiceAlamofireBaseEngine {
    private let sessionManager: Alamofire.SessionManager
    
    public init(sessionManager: Alamofire.SessionManager = Alamofire.SessionManager.default, queueForRequest: DispatchQueue? = nil, useNetworkActivityIndicator: Bool = true) {
        self.sessionManager = sessionManager
        super.init(queueForRequest: queueForRequest, useNetworkActivityIndicator: useNetworkActivityIndicator)
    }
    
    public override func isSupportedRequest(_ request: WebServiceBaseRequesting, rawDataTypeForRestoreFromStorage: Any.Type?) -> Bool {
        return request is WebServiceAlamofireBaseRequesting
    }
    
    public override func performRequest(requestId: UInt64, data: WebServiceAlamofireBaseEngine.RequestData) throws -> DataRequest? {
        guard let request = data.request as? WebServiceAlamofireBaseRequesting else {
            throw WebServiceRequestError.notSupportRequest
        }
        
        return try request.afRequest(sessionManager: sessionManager)
    }
    
    public override func responseAlamofire(_ response: DataResponse<Data>, requestId: UInt64, requestData: WebServiceAlamofireBaseEngine.RequestData) throws -> Any {
        switch response.result {
        case .success(let data):
            if let statusCode = response.response?.statusCode, statusCode >= 300 {
                throw WebServiceResponseError.httpStatusCode(statusCode)
            }
            
            return data
            
        case .failure(let error):
            throw error
        }
    }
    
    public override func dataHandler(request: WebServiceBaseRequesting, data: Any, isRawFromStorage: Bool) throws -> Any? {
        guard let binary = data as? Data, let request = request as? WebServiceAlamofireBaseRequesting else {
            throw WebServiceRequestError.notSupportDataHandler
        }
        
        switch request.afResponseType {
        case .binary:
            return try request.afBaseDecodeResponse(WebServiceAlamofireResponseData(binary: binary))
            
        case .json:
            let jsonData = try JSONSerialization.jsonObject(with: binary, options: [])
            return try request.afBaseDecodeResponse(WebServiceAlamofireResponseData(json: jsonData))
        }
    }
    
}
