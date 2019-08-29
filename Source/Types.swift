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

public enum RequestCanceledReason: Hashable {
    case duplicate
    case user
    case destroyed
    case unknown
}

/**
 Result response for concrete type from gateway
 
 - `data(T)`: Success response with data with require type
 - `error(Error)`: Error response
 - `canceledRequest`: Reqest canceled (called `WebService.cancelRequests()` method for this request)
 - `duplicateRequest`: If `excludeDuplicate == true` and this request contained in queue
 */
public enum Response<T> {
    case success(T)
    case failure(Error)
    case canceled(RequestCanceledReason)

    /// Data if success response
    public var result: T? {
        switch self {
        case .success(let r): return r
        default: return nil
        }
    }
    
    /// Error if response completed with error
    public var error: Error? {
        switch self {
        case .failure(let err): return err
        default: return nil
        }
    }
    
    /// Is canceled request, also true when duplicated request
    public var isCanceled: Bool {
        switch self {
        case .canceled: return true
        default: return false
        }
    }
    
    /// Canceled reason if canceled
    public var canceledReason: RequestCanceledReason? {
        switch self {
        case .canceled(let reason): return reason
        default: return nil
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
        case .success(let data):
            if let data = data as? T {
                return .success(data)
            } else {
                return .failure(ResponseError.invalidData(ConvertError(from: type(of: data), to: T.self)))
            }
            
        case .failure(let error):
            return .failure(error)
            
        case .canceled(let reason):
            return .canceled(reason)
        }
    }
}
