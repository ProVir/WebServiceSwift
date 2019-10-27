//
//  NetworkRequestPerfomer.swift
//  WebServiceSwift
//
//  Created by Vitalii Korotkii on 20/09/2019.
//  Copyright © 2019 ProVir. All rights reserved.
//

import Foundation

public extension NetworkPerfomerFactory {
    func make<T: NetworkRequest>(requestType: T.Type) -> NetworkRequestPerfomer<T> {
        return make(NetworkRequestPerfomer<T>.self)
    }
}

public final class NetworkRequestPerfomer<RequestType: NetworkRequest>: NetworkPerfomer {
    private let session: NetworkSession
    private var internalExcludeDuplicateDefault: Bool = false

    public init(session: NetworkSession) {
        self.session = session
    }

    // MARK: Perform requests
    @discardableResult
    public func perform(
        request: RequestType,
        storageDependency: NetworkStorageDependency? = nil,
        completion: @escaping (_ result: NetworkResult<RequestType.ResponseType>) -> Void
        ) -> NetworkRequestTask {
        return session.perform(request: request,
                               excludeDuplicate: internalExcludeDuplicateDefault,
                               storageDependency: storageDependency,
                               completion: completion)
    }

    @discardableResult
    public func perform(
        request: RequestType,
        key: NetworkBaseRequestKey,
        excludeDuplicate: Bool,
        storageDependency: NetworkStorageDependency? = nil,
        completion: @escaping (_ result: NetworkResult<RequestType.ResponseType>) -> Void
        ) -> NetworkRequestTask {
        return session.perform(request: request,
                               key: key,
                               excludeDuplicate: excludeDuplicate,
                               storageDependency: storageDependency,
                               completion: completion)
    }

    // MARK: Control requests
    public func tasks(filter: NetworkRequestFilter? = nil) -> [NetworkRequestTask] {
        return session.tasks(filter: updatedFilter(filter))
    }

    public func containsRequest(filter: NetworkRequestFilter? = nil) -> Bool {
        return session.containsRequest(filter: updatedFilter(filter))
    }

    @discardableResult
    public func cancelRequests(filter: NetworkRequestFilter? = nil) -> [NetworkRequestTask] {
        return session.cancelRequests(filter: updatedFilter(filter))
    }

    private func updatedFilter(_ filter: NetworkRequestFilter?) -> NetworkRequestFilter {
        if let filter = filter {
            return .and([.init(requestType: RequestType.self), filter])
        } else {
            return .init(requestType: RequestType.self)
        }
    }
}

extension NetworkRequestPerfomer where RequestType: NetworkEmptyRequest {
    @discardableResult
    public func perform(
        storageDependency: NetworkStorageDependency? = nil,
        completion: @escaping (_ result: NetworkResult<RequestType.ResponseType>) -> Void
        ) -> NetworkRequestTask {
        return session.perform(request: RequestType(),
                               excludeDuplicate: internalExcludeDuplicateDefault,
                               storageDependency: storageDependency,
                               completion: completion)
    }
}

// MARK: Hashable requests
extension NetworkRequestPerfomer where RequestType: Hashable {
    /// Default excludeDuplicate for hashable requests.
    public var excludeDuplicateDefault: Bool {
        get { return internalExcludeDuplicateDefault }
        set { internalExcludeDuplicateDefault = newValue }
    }

    @discardableResult
    public func perform(
        request: RequestType,
        excludeDuplicate: Bool,
        storageDependency: NetworkStorageDependency? = nil,
        completion: @escaping (_ result: NetworkResult<RequestType.ResponseType>) -> Void
        ) -> NetworkRequestTask {
        return session.perform(request: request,
                               excludeDuplicate: excludeDuplicate,
                               storageDependency: storageDependency,
                               completion: completion)
    }
}

// MARK: Storage
extension NetworkRequestPerfomer where RequestType: NetworkRequestBaseStorable {
    @discardableResult
    public func fetch(
        request: RequestType,
        completion: @escaping (_ timeStamp: Date?, _ result: NetworkStorageResult<RequestType.ResponseType>) -> Void
        ) -> NetworkStorageTask {
        return session.fetch(request: request, completion: completion)
    }

    public func deleteInStorage(request: RequestType) {
        session.deleteInStorage(request: request)
    }
}

extension NetworkRequestPerfomer where RequestType: NetworkRequestBaseStorable, RequestType: NetworkEmptyRequest {
    @discardableResult
    public func fetch(
        completion: @escaping (_ timeStamp: Date?, _ result: NetworkStorageResult<RequestType.ResponseType>) -> Void
        ) -> NetworkStorageTask {
        return session.fetch(request: RequestType(), completion: completion)
    }

    public func deleteInStorage() {
        session.deleteInStorage(request: RequestType())
    }
}
