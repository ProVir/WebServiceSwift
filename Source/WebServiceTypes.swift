//
//  WebServiceTypes.swift
//  WebServiceSwift 3.0.0
//
//  Created by Короткий Виталий (ViR) on 16.04.2018.
//  Updated to 3.0.0 by Короткий Виталий (ViR) on 19.06.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation

/**
 WebService general error enum for requests
 
 - `noFoundEndpoint`: If endpoint not found in `[endpoints]` for request
 - `noFoundStorage`: If storage not found in `[storages]` for request
 - `notSupportRequest`: If request after test fot endpoint contains invalid query or etc.
 - `notSupportDataHandler`: If request don't support data handler
 */
public enum WebServiceRequestError: Error {
    case notFoundEndpoint
    case notFoundStorage
    
    case notSupportRequest
    case notSupportDataHandler
}

/**
 WebService general error enum for response
 
 - `invalidData`: If data from server or decoder invalid
 - `httpStatusCode(Code)`: HTTP Status code != 200 and as error
 - `general(code, data)`: Custom error with code and data
 */
public enum WebServiceResponseError: Error {
    ///Data from server invalid
    case invalidData
    
    /// Data not found in storage
    case notFoundData
    
    ///General error http status code
    case httpStatusCode(Int)
    
    /// Code + data
    case general(Int, Any?)
}

/**
 WebService result response for concrete type from endpoint
 
 - `data(T)`: Success response with data with requre type
 - `error(Error)`: Error response
 - `canceledRequest`: Reqest canceled (called `WebService.cancelRequest()` method for this request or group requests)
 - `duplicateRequest`: If `excludeDuplicateRequests == true` and this request contained in queue
 */
public enum WebServiceResponse<T> {
    case data(T)
    case error(Error)
    case canceledRequest
    case duplicateRequest
    
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
    
    /// Is canceled request
    public var isCanceled: Bool {
        switch self {
        case .canceledRequest: return true
        default: return false
        }
    }
    
    /// Error duplicate for request
    public var isDuplicateError: Bool {
        switch self {
        case .duplicateRequest: return true
        default: return false
        }
    }
}

/// WebService result response from endpoint without information for type
public typealias WebServiceAnyResponse = WebServiceResponse<Any?>

extension WebServiceResponse where T == Any? {
    /// Data if success response
    public func dataAnyResponse() -> Any? {
        switch self {
        case .data(let d): return d
        default: return nil
        }
    }
}

///Response from other type
public extension WebServiceResponse {
    
    ///Convert to response with other type data automatic.
    func convert<T>() -> WebServiceResponse<T> {
        return convert(T.self)
    }
    
    ///Convert to response with type from request
    func convert<RequestType: WebServiceRequesting>(request: RequestType) -> WebServiceResponse<RequestType.ResultType> {
        return convert(RequestType.ResultType.self)
    }
    
    ///Convert to response with concrete other type data.
    func convert<T>(_ typeData: T.Type) -> WebServiceResponse<T> {
        switch self {
        case .data(let data):
            if let data = data as? T {
                return .data(data)
            } else {
                return .error(WebServiceResponseError.invalidData)
            }
            
        case .error(let error):
            return .error(error)
            
        case .canceledRequest:
            return .canceledRequest
            
        case .duplicateRequest:
            return .duplicateRequest
        }
    }
}

