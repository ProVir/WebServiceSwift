//
//  Types.swift
//  WebServiceSwift 4.0.0
//
//  Created by Короткий Виталий (ViR) on 16.04.2018.
//  Updated to 3.0.0 by Короткий Виталий (ViR) on 04.09.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation

/// Base protocol for all types request.
public protocol BaseRequest { }

/// Generic protocol with information result type for all types request.
public protocol Request: BaseRequest {
    /// Type for response data when success. For data without data you can use Void or Any?
    associatedtype ResultType
}

/// Generic protocol without parameters for server and with information result type for all types request.
public protocol EmptyRequest: Request {
    init()
}

/// RawData for Gateway
public protocol StorageRawData { }
extension Data: StorageRawData { }

/**
 General error enum for requests
 
 - `noFoundGateway`: If gateway not found in `[gateways]` for request
 - `noFoundStorage`: If storage not found in `[storages]` for request
 - `notSupportRequest`: If request after test fot gateway contains invalid query or etc.
 - `notSupportDataHandler`: If request don't support data handler
 - `invalidRequest`: Validation request and create request to server failed.
 - `gatewayInternal`: Internal error in gateway.
 */
public enum RequestError: Error {
    case notFoundGateway
    case notFoundStorage
    
    case notSupportRequest
    case notSupportDataProcessing
    
    case invalidRequest(Error)
    case gatewayInternal
}

/// General error enum for response
public enum ResponseError: Error {
    /// Data from server invalid. Usually error value is `WebServiceResponse.ConvertError` or `DecoderError`
    case invalidData(Error)

    /// Data not found in storage
    case notFoundData
    
    /// General error http status code (usually when != 200)
    case httpStatusCode(Int)
}

/**
 Result response for concrete type from gateway
 
 - `data(T)`: Success response with data with require type
 - `error(Error)`: Error response
 - `canceledRequest`: Reqest canceled (called `WebService.cancelRequests()` method for this request)
 - `duplicateRequest`: If `excludeDuplicate == true` and this request contained in queue
 */
public enum Response<T> {
    case data(T)
    case error(Error)
    case canceledRequest(duplicate: Bool)
    
    /// Data if success response
    public func dataResponse() -> T? {
        switch self {
        case .data(let d): return d
        default: return nil
        }
    }
    
    /// Error if response completed with error
    public func errorResponse() -> Error? {
        switch self {
        case .error(let err): return err
        default: return nil
        }
    }
    
    /// Is canceled request, also true when duplicated request
    public var isCanceled: Bool {
        switch self {
        case .canceledRequest: return true
        default: return false
        }
    }
    
    /// Canceled becouse duplicate request
    public var isDuplicate: Bool {
        switch self {
        case .canceledRequest(duplicate: let duplicate): return duplicate
        default: return false
        }
    }
}

///Response from other type
public extension Response {
    struct ConvertError: Error {
        let from: Any.Type
        let to: Any.Type
    }
    
    ///Convert to response with other type data automatic.
    func convert<T>() -> Response<T> {
        return convert(T.self)
    }
    
    ///Convert to response with type from request
    func convert<RequestType: Request>(request: RequestType) -> Response<RequestType.ResultType> {
        return convert(RequestType.ResultType.self)
    }
    
    ///Convert to response with concrete other type data.
    func convert<T>(_ typeData: T.Type) -> Response<T> {
        switch self {
        case .data(let data):
            if let data = data as? T {
                return .data(data)
            } else {
                return .error(ResponseError.invalidData(ConvertError(from: type(of: data), to: T.self)))
            }
            
        case .error(let error):
            return .error(error)
            
        case .canceledRequest(duplicate: let duplicate):
            return .canceledRequest(duplicate: duplicate)
        }
    }
}
