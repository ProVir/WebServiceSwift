//
//  AlamofireSimpleGateway.swift
//  WebServiceSwift 4.0.0
//
//  Created by Короткий Виталий (ViR) on 01.06.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation
import Alamofire


// MARK: Request

/// Base protocol for request use AlamofireSimpleGateway
public protocol AlamofireSimpleBaseRequesting {
    /// Create alamofire request with use session manager.
    func afRequest(sessionManager: Alamofire.Session) throws -> Alamofire.DataRequest

    /// Response type (binary or json) for decode response.
    var afResponseType: AlamofireSimpleResponseType { get }
    
    /// Decode response to value. Used `data.binary` or `data.json` dependency from `afResponseType` parameter. Perofrm in background thread.
    func afBaseDecodeResponse(_ data: AlamofireSimpleResponseData) throws -> Any
}

public protocol AlamofireSimpleRequesting: AlamofireSimpleBaseRequesting, WebServiceRequesting {
    /// Decode response to value. Used `data.binary` or `data.json` dependency from `afResponseType` parameter. Perofrm in background thread.
    func afDecodeResponse(_ data: AlamofireSimpleResponseData) throws -> ResultType
}

public extension AlamofireSimpleRequesting {
    func afBaseDecodeResponse(_ data: AlamofireSimpleResponseData) throws -> Any {
        return try afDecodeResponse(data)
    }
}

// MARK: Response
/// Response type to require for decoder
public enum AlamofireSimpleResponseType {
    case binary
    case json
}

/// Response data for decoder
public enum AlamofireSimpleResponseData {
    case binary(Data)
    case json(Any)
    
    /// Get binary data for decoder
    public func binary() throws -> Data {
        if case let .binary(value) = self {
            return value
        } else {
            throw WebServiceRequestError.gatewayInternal
        }
    }
    
    /// Get json data for decoder
    public func json() throws -> Any {
        if case let .json(value) = self {
            return value
        } else {
            throw WebServiceRequestError.gatewayInternal
        }
    }
}

// MARK: Auto decoders
/// Protocol for enable auto implementation response decoder (afResponseType and afDecodeResponse) for certain result types.
protocol AlamofireSimpleAutoDecoder: WebServiceRequesting { }

/// Support AutoDecoder for request, when ignored result data from server (ResultType = Void).
extension AlamofireSimpleAutoDecoder where ResultType == Void {
    var afResponseType: AlamofireSimpleResponseType { return .binary }
    func afDecodeResponse(_ data: AlamofireSimpleResponseData) throws -> Void {
        return Void()
    }
}

/// Support AutoDecoder for binary reslt type (ResultType = Data)
extension AlamofireSimpleAutoDecoder where ResultType == Data {
    var afResponseType: AlamofireSimpleResponseType { return .binary }
    func afDecodeResponse(_ data: AlamofireSimpleResponseData) throws -> Data {
        return try data.binary()
    }
}


// MARK: Gateway
/// Simple HTTP Gateway (use Alamofire)
public class AlamofireSimpleGateway: AlamofireGateway {
    /**
     Simple HTTP Gateway used Alamofire constructor.

     - Parameters:
        - sessionManager: Alamofire.SessionManager for use, default Alamofire.SessionManager.default.
        - queueForRequest: Thread Dispatch Queue for `perofrmRequest()` and `cancelRequests()` methods.
        - useNetworkActivityIndicator: When `true`, showed networkActivityIndicator in statusBar when requests in process.
     */
    public init(sessionManager: Alamofire.Session = .default, queueForRequest: DispatchQueue? = nil, useNetworkActivityIndicator: Bool = true) {
        let handler = AlamofireSimpleGatewayHandler(sessionManager: sessionManager)
        super.init(queueForRequest: queueForRequest, useNetworkActivityIndicator: useNetworkActivityIndicator, handler: handler)
    }
}

public class AlamofireSimpleGatewayHandler: AlamofireGatewayHandler {
    private let sessionManager: Alamofire.Session

    public init(sessionManager: Alamofire.Session = .default) {
        self.sessionManager = sessionManager
    }

    public func isSupportedRequest(_ request: WebServiceBaseRequesting, forDataProcessingFromStorage rawDataType: WebServiceStorageRawData.Type?) -> Bool {
        return request is AlamofireSimpleBaseRequesting
    }

    public func makeAlamofireRequest(requestId: UInt64, request: WebServiceBaseRequesting, completion: @escaping (AlamofireGateway.RequestResult) -> Void) {
        do {
            guard let request = request as? AlamofireSimpleBaseRequesting else {
                throw WebServiceRequestError.notSupportRequest
            }

            let afRequest = try request.afRequest(sessionManager: sessionManager)
            completion(.success(afRequest, innerData: nil))
        } catch {
            completion(.failure(error))
        }
    }

    public func responseAlamofire(_ response: DataResponse<Data>, requestId: UInt64, request: WebServiceBaseRequesting, innerData: Any?) throws -> WebServiceGatewayResponse {
        guard let request = request as? AlamofireSimpleBaseRequesting else {
            throw WebServiceRequestError.notSupportDataProcessing
        }

        switch response.result {
        case .success(let data):
            //Validation data for http status code
            if let statusCode = response.response?.statusCode, statusCode >= 300 {
                throw WebServiceResponseError.httpStatusCode(statusCode)
            }

            let result = try dataProcessing(request: request, binary: data)
            return WebServiceGatewayResponse(result: result, rawDataForStorage: data)

        case .failure(let error):
            throw error
        }
    }

    public func dataProcessingFromStorage(request: WebServiceBaseRequesting, rawData: WebServiceStorageRawData) throws -> Any {
        guard let binary = rawData as? Data, let request = request as? AlamofireSimpleBaseRequesting else {
            throw WebServiceRequestError.notSupportDataProcessing
        }

        return try dataProcessing(request: request, binary: binary)
    }

    private func dataProcessing(request: AlamofireSimpleBaseRequesting, binary: Data) throws -> Any {
        switch request.afResponseType {
        case .binary:
            return try request.afBaseDecodeResponse(AlamofireSimpleResponseData.binary(binary))

        case .json:
            let jsonData = try JSONSerialization.jsonObject(with: binary, options: [])
            return try request.afBaseDecodeResponse(AlamofireSimpleResponseData.json(jsonData))
        }
    }
}
