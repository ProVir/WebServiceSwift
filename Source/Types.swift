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
public protocol NetworkBaseRequest { }

/// Generic protocol with information result type for all types request.
public protocol NetworkRequest: NetworkBaseRequest {
    /// Type for response data when success. For data without data you can use Void or Any?
    associatedtype ResultType
}

/// Generic protocol without parameters for server and with information result type for all types request.
public protocol NetworkEmptyRequest: NetworkRequest {
    init()
}

public protocol NetworkRequestKey: NetworkBaseRequestKey, Hashable { }

public protocol NetworkBaseRequestKey {
    func hash(into hasher: inout Hasher)
    func isEqual(_ key: NetworkBaseRequestKey) -> Bool
}

public extension NetworkRequestKey {
    func isEqual(_ key: NetworkBaseRequestKey) -> Bool {
        guard let key = key as? Self else { return false }
        return key == self
    }
}

/// RawData for Gateway
public protocol NetworkStorageRawData { }
extension Data: NetworkStorageRawData { }

/// RequestId for gateway
public struct NetworkRequestId: RawRepresentable, Hashable, Comparable {
    public let value: UInt64
    public init(_ value: UInt64) {
        self.value = value
    }

    public init?(rawValue: UInt64) {
        self.value = rawValue
    }

    public var rawValue: UInt64 {
        return value
    }

    public static func < (lhs: NetworkRequestId, rhs: NetworkRequestId) -> Bool {
        return lhs.value < rhs.value
    }
}

/**
 General errors

 - `noFoundGateway`: If gateway not found in `[gateways]` for request
 - `notSupportRequest`: If request after test fot gateway contains invalid query or etc
 - `invalidTypeResult`: Invalid result type from gateway
 - `unknown`: Unknown error in gateway
 */
public enum NetworkError: Error {
    case notFoundGateway
    case notSupportRequest
    case invalidTypeResult(Any.Type, require: Any.Type)
    case unknown
}

/**
 Storage errors

 - `notFoundData`: Data not found in storage
 - `noFoundStorage`: If storage not found in `[storages]` for request
 - `noFoundGateway`: If gateway not found in `[gateways]` for data processing readed raw data
 - `failureFetch`: Error fetch in storage
 - `failureDataProcessing`: Error data processing readed raw data in gateway
  - `invalidTypeResult`: Invalid result type from storage or gateway
 */
public enum NetworkStorageError: Error {
    case notFoundData
    case notFoundStorage
    case notFoundGateway
    case failureFetch(Error)
    case failureDataProcessing(Error)
    case invalidTypeResult(Any.Type, require: Any.Type)

    public var isNotFoundData: Bool {
        switch self {
        case .notFoundData: return true
        default: return false
        }
    }
}

public enum NetworkRequestCanceledReason: Hashable {
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
public enum NetworkBaseResponse<T, E: Error> {
    case success(T)
    case failure(E)
    case canceled(NetworkRequestCanceledReason)

    /// Data if success response
    public var result: T? {
        switch self {
        case .success(let r): return r
        default: return nil
        }
    }

    /// Error if response completed with error
    public var error: E? {
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
    public var canceledReason: NetworkRequestCanceledReason? {
        switch self {
        case .canceled(let reason): return reason
        default: return nil
        }
    }
}

public typealias NetworkResponse<T> = NetworkBaseResponse<T, Error>
public typealias NetworkStorageResponse<T> = NetworkBaseResponse<T, NetworkStorageError>


///Response from other type
public extension NetworkBaseResponse where E == Error {
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
            
        case .failure(let error):
            return .failure(error)
            
        case .canceled(let reason):
            return .canceled(reason)
        }
    }
}

///Response from storage from other type
public extension NetworkBaseResponse where E == NetworkStorageError {
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

        case .failure(let error):
            return .failure(error)

        case .canceled(let reason):
            return .canceled(reason)
        }
    }

    func convertFailure() -> NetworkResponse<T> {
        switch self {
        case .success(let r): return .success(r)
        case .failure(let e): return .failure(e)
        case .canceled(let r): return .canceled(r)
        }
    }
}

// Filter for find requests
public struct NetworkRequestFilter {
    enum Value {
        case request(NetworkBaseRequest)   //BaseRequest & Hashable
        case requestType(NetworkBaseRequest.Type)
        case key(NetworkBaseRequestKey)
        case keyType(NetworkRequestFilterKeyTypeWrapper)  //KeyTypeWrapper<Hashable>
        case and([Value])
        case or([Value])
    }
    let value: Value

    public init<RequestType: NetworkBaseRequest & Hashable>(request: RequestType) { value = .request(request) }
    public init(requestType: NetworkBaseRequest.Type) { value = .requestType(requestType) }
    public init<K: NetworkBaseRequestKey>(key: K) { value = .key(key) }
    public init<K: NetworkBaseRequestKey>(keyType: K.Type) { value = .keyType(KeyTypeWrapper<K>()) }
    public init(and list: [NetworkRequestFilter]) { value = .and(list.map { $0.value }) }
    public init(or list: [NetworkRequestFilter]) { value = .or(list.map { $0.value }) }

    public static func request<RequestType: NetworkBaseRequest & Hashable>(_ request: RequestType) -> NetworkRequestFilter { return .init(request: request) }
    public static func requestType(_ requestType: NetworkBaseRequest.Type) -> NetworkRequestFilter { return .init(requestType: requestType) }
    public static func key<K: NetworkBaseRequestKey>(_ key: K) -> NetworkRequestFilter { return .init(key: key) }
    public static func keyType<K: NetworkBaseRequestKey>(_ keyType: K.Type) -> NetworkRequestFilter { return .init(keyType: keyType) }
    public static func and(_ list: [NetworkRequestFilter]) -> NetworkRequestFilter { return .init(and: list) }
    public static func or(_ list: [NetworkRequestFilter]) -> NetworkRequestFilter { return .init(or: list) }

    struct KeyTypeWrapper<K: NetworkBaseRequestKey>: NetworkRequestFilterKeyTypeWrapper {
        func isEqualType(key: NetworkBaseRequestKey) -> Bool { return key is K }
    }
}

protocol NetworkRequestFilterKeyTypeWrapper {
    func isEqualType(key: NetworkBaseRequestKey) -> Bool
}

struct NetworkRequestKeyWrapper: Hashable {
    let key: NetworkBaseRequestKey

    func hash(into hasher: inout Hasher) {
        key.hash(into: &hasher)
    }

    static func == (lhs: NetworkRequestKeyWrapper, rhs: NetworkRequestKeyWrapper) -> Bool {
        return lhs.key.isEqual(rhs.key)
    }
}
