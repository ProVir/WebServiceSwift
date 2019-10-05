//
//  Response.swift
//  WebServiceSwift
//
//  Created by Vitalii Korotkii on 20/09/2019.
//  Copyright © 2019 ProVir. All rights reserved.
//

import Foundation

public enum NetworkRequestCanceledReason: Hashable {
    case duplicate
    case user
    case destroyed
    case unknown
}

public enum NetworkStorageCanceledReason: Hashable {
    case user
    case dependSuccess
    case dependFailure
    case dependCanceled(NetworkRequestCanceledReason)
    case unknown
}


// MARK: Responses
/**
 Result response for concrete type from gateway

 - `data(T)`: Success response with data with require type
 - `error(Error)`: Error response
 - `canceledRequest`: Reqest canceled (called `WebService.cancelRequests()` method for this request)
 - `duplicateRequest`: If `excludeDuplicate == true` and this request contained in queue
 */
public enum NetworkResponse<T> {
    case success(T)
    case failure(Error)
    case canceled(NetworkRequestCanceledReason)
}


public enum NetworkStorageResponse<T> {
    case success(T)
    case notFound
    case failure(NetworkStorageError)
    case canceled(NetworkStorageCanceledReason)
}

public extension NetworkResponse {
    /// Data if success response
    var result: T? {
        switch self {
        case .success(let r): return r
        default: return nil
        }
    }

    /// Error if response completed with error
    var error: Error? {
        switch self {
        case .failure(let err): return err
        default: return nil
        }
    }

    /// Is canceled request, also true when duplicated request
    var isCanceled: Bool {
        switch self {
        case .canceled: return true
        default: return false
        }
    }

    /// Canceled reason if canceled
    var canceledReason: NetworkRequestCanceledReason? {
        switch self {
        case .canceled(let reason): return reason
        default: return nil
        }
    }
}

public extension NetworkStorageResponse {
    /// Data if success response
    var result: T? {
        switch self {
        case .success(let r): return r
        default: return nil
        }
    }

    var isNotFound: Bool {
        switch self {
        case .notFound: return true
        default: return false
        }
    }

    /// Error if response completed with error
    var error: NetworkStorageError? {
        switch self {
        case .failure(let err): return err
        default: return nil
        }
    }

    /// Is canceled request, also true when duplicated request
    var isCanceled: Bool {
        switch self {
        case .canceled: return true
        default: return false
        }
    }

    /// Canceled reason if canceled
    var canceledReason: NetworkStorageCanceledReason? {
        switch self {
        case .canceled(let reason): return reason
        default: return nil
        }
    }
}

// MARK: Converters

///Response from other type
public extension NetworkResponse {
    ///Convert to response with other type data automatic.
    func convert<T>() -> NetworkResponse<T> {
        return convert(T.self)
    }

    ///Convert to response with type from request
    func convert<RequestType: NetworkRequest>(request: RequestType) -> NetworkResponse<RequestType.ResultType> {
        return convert(RequestType.ResultType.self)
    }

    ///Convert to response with concrete other type data.
    func convert<T>(_ typeData: T.Type) -> NetworkResponse<T> {
        switch self {
        case .success(let data):
            if let data = data as? T {
                return .success(data)
            } else {
                return .failure(NetworkError.invalidTypeResult(type(of: data), require: T.self))
            }

        case .failure(let error): return .failure(error)
        case .canceled(let reason): return .canceled(reason)
        }
    }
}

///Response from storage from other type
public extension NetworkStorageResponse {
    ///Convert to response with other type data automatic.
    func convert<T>() -> NetworkStorageResponse<T> {
        return convert(T.self)
    }

    ///Convert to response with type from request
    func convert<RequestType: NetworkRequest>(request: RequestType) -> NetworkStorageResponse<RequestType.ResultType> {
        return convert(RequestType.ResultType.self)
    }

    ///Convert to response with concrete other type data.
    func convert<T>(_ typeData: T.Type) -> NetworkStorageResponse<T> {
        switch self {
        case .success(let data):
            if let data = data as? T {
                return .success(data)
            } else {
                return .failure(.invalidTypeResult(type(of: data), require: T.self))
            }

        case .notFound: return .notFound
        case .failure(let error): return .failure(error)
        case .canceled(let reason): return .canceled(reason)
        }
    }

    func convertToCommon() -> NetworkResponse<T> {
        switch self {
        case .success(let r): return .success(r)
        case .notFound: return .failure(NetworkStorageError.notFoundData)
        case .failure(let e): return .failure(e)
        case .canceled(let r):
            switch r {
            case .user: return .canceled(.user)
            case .dependSuccess, .dependFailure: return .canceled(.unknown)
            case .dependCanceled(let r): return .canceled(r)
            case .unknown: return .canceled(.unknown)
            }
        }
    }
}
