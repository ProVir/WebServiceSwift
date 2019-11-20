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


// MARK: Results
/**
 Result response for concrete type from gateway

 - `data(Response)`: Success response with data with require type
 - `error(Error)`: Error response
 - `canceledRequest`: Reqest canceled (called `WebService.cancelRequests()` method for this request)
 - `duplicateRequest`: If `excludeDuplicate == true` and this request contained in queue
 */
public enum NetworkResult<Response> {
    case success(Response)
    case failure(Error)
    case canceled(NetworkRequestCanceledReason)
}


public enum NetworkStorageResult<Response> {
    case success(Response, saved: Date?)
    case notFound
    case failure(NetworkStorageError)
    case canceled(NetworkStorageCanceledReason)
}

public extension NetworkResult {
    /// Data if success response
    var response: Response? {
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

public extension NetworkStorageResult {
    /// Data if success response
    var response: Response? {
        switch self {
        case let .success(r, _): return r
        default: return nil
        }
    }

    var timeStamp: Date? {
        switch self {
        case let .success(_, t): return t
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
public extension NetworkResult {
    ///Convert to response with other type data automatic.
    func convert<T>() -> NetworkResult<T> {
        return convert(T.self)
    }

    ///Convert to response with type from request
    func convert<RequestType: NetworkRequest>(request: RequestType) -> NetworkResult<RequestType.ResponseType> {
        return convert(RequestType.ResponseType.self)
    }

    ///Convert to response with concrete other type data.
    func convert<T>(_ typeData: T.Type) -> NetworkResult<T> {
        switch self {
        case .success(let data):
            if let data = data as? T {
                return .success(data)
            } else {
                return .failure(NetworkError.invalidTypeResponse(type(of: data), require: T.self))
            }

        case .failure(let error): return .failure(error)
        case .canceled(let reason): return .canceled(reason)
        }
    }
}

///Response from storage from other type
public extension NetworkStorageResult {
    ///Convert to response with other type data automatic.
    func convert<T>() -> NetworkStorageResult<T> {
        return convert(T.self)
    }

    ///Convert to response with type from request
    func convert<RequestType: NetworkRequest>(request: RequestType) -> NetworkStorageResult<RequestType.ResponseType> {
        return convert(RequestType.ResponseType.self)
    }

    ///Convert to response with concrete other type data.
    func convert<T>(_ typeData: T.Type) -> NetworkStorageResult<T> {
        switch self {
        case let .success(data, timeStamp):
            if let data = data as? T {
                return .success(data, saved: timeStamp)
            } else {
                return .failure(.invalidTypeResponse(type(of: data), require: T.self))
            }

        case .notFound: return .notFound
        case .failure(let error): return .failure(error)
        case .canceled(let reason): return .canceled(reason)
        }
    }

    func convertToCommon() -> NetworkResult<Response> {
        switch self {
        case .success(let r, _): return .success(r)
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
