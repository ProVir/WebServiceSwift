//
//  Session.swift
//  WebServiceSwift 4.0.0
//
//  Created by Vitalii Korotkii on 02/09/2019.
//  Copyright © 2019 ProVir. All rights reserved.
//

import Foundation

public struct NetworkSessionConfiguration {
    public var gateways: [NetworkBaseGateway]
    public var storages: [NetworkBaseStorage]

    /// Perform response closures and delegates in dispath queue. Default: main thread.
    public var queueForResponse: DispatchQueue

    /// Ignore gateway parameter and always don't use networkActivityIndicator in statusBar when requests in process.
    public var disableNetworkActivityIndicator: Bool

    public init(gateways: [NetworkBaseGateway],
                storages: [NetworkBaseStorage],
                queueForResponse: DispatchQueue = .main,
                disableNetworkActivityIndicator: Bool = false) {
        self.gateways = gateways
        self.storages = storages
        self.queueForResponse = queueForResponse
        self.disableNetworkActivityIndicator = disableNetworkActivityIndicator
    }
}

public final class NetworkSession {
    private let gatewaysManager: GatewaysManager
    private let storagesManager: StoragesManager

    public init(_ config: NetworkSessionConfiguration) {
        self.gatewaysManager = GatewaysManager(config: config)
        self.storagesManager = StoragesManager(config: config)

        gatewaysManager.setup(responseExternalHandler: { [weak storagesManager] (request, result) in
            if let request = request as? NetworkRequestBaseStorable {
                storagesManager?.handleResponse(request: request, result: result)
            }
        })

        storagesManager.setup(rawDataProcessingHandler: { [weak gatewaysManager] (request, rawData, completion) in
            gatewaysManager?.rawDataProcessing(request: request, rawData: rawData, completion: completion)
        })
    }

    // MARK: Make tasks for perform later
    public func makeTask(
        baseRequest: NetworkBaseRequest,
        key: NetworkBaseRequestKey?,
        excludeDuplicate: Bool,
        storageDependency: NetworkStorageDependency?,
        canRepeat: Bool,
        completion: @escaping (_ result: NetworkResult<Any>) -> Void
    ) -> NetworkRequestTask {
        return gatewaysManager.makeTask(
            request: baseRequest,
            key: key,
            excludeDuplicate: excludeDuplicate,
            storageDependency: storageDependency,
            canRepeat: canRepeat,
            completion: completion
        )
    }

    public func makeTask<RequestType: NetworkRequest>(
        request: RequestType,
        key: NetworkBaseRequestKey? = nil,
        excludeDuplicate: Bool = false,
        storageDependency: NetworkStorageDependency? = nil,
        canRepeat: Bool = false,
        completion: @escaping (_ result: NetworkResult<RequestType.ResponseType>) -> Void
    ) -> NetworkRequestTask {
        return gatewaysManager.makeTask(
            request: request,
            key: key,
            excludeDuplicate: excludeDuplicate,
            storageDependency: storageDependency,
            canRepeat: canRepeat,
            completion: { completion( $0.convert() ) }
        )
    }

    // MARK: Perform requests
    @discardableResult
    public func perform(
        baseRequest: NetworkBaseRequest,
        key: NetworkBaseRequestKey?,
        excludeDuplicate: Bool,
        storageDependency: NetworkStorageDependency?,
        completion: @escaping (_ result: NetworkResult<Any>) -> Void
    ) -> NetworkRequestTask {
        return gatewaysManager.perform(
            request: baseRequest,
            key: key,
            excludeDuplicate: excludeDuplicate,
            storageDependency: storageDependency,
            completion: completion
        )
    }

    @discardableResult
    public func perform<RequestType: NetworkRequest>(
        request: RequestType,
        key: NetworkBaseRequestKey? = nil,
        excludeDuplicate: Bool = false,
        storageDependency: NetworkStorageDependency? = nil,
        completion: @escaping (_ result: NetworkResult<RequestType.ResponseType>) -> Void
    ) -> NetworkRequestTask {
        return gatewaysManager.perform(
            request: request,
            key: key,
            excludeDuplicate: excludeDuplicate,
            storageDependency: storageDependency,
            completion: { completion( $0.convert() ) }
        )
    }

    // MARK: Read storage
    public func makeFetchTask(baseRequest: NetworkRequestBaseStorable, completion: @escaping (_ timeStamp: Date?, _ result: NetworkStorageResult<Any>) -> Void) -> NetworkStorageTask {
        return storagesManager.makeFetchTask(request: baseRequest, completion: completion)
    }

    public func makeFetchTask<RequestType: NetworkRequest & NetworkRequestBaseStorable>(
        request: RequestType,
        completion: @escaping (_ timeStamp: Date?, _ result: NetworkStorageResult<RequestType.ResponseType>) -> Void
    ) -> NetworkStorageTask {
        return storagesManager.makeFetchTask(request: request, completion: { completion( $0, $1.convert() ) })
    }

    @discardableResult
    public func fetch(baseRequest: NetworkRequestBaseStorable, completion: @escaping (_ timeStamp: Date?, _ result: NetworkStorageResult<Any>) -> Void) -> NetworkStorageTask {
        return storagesManager.fetch(request: baseRequest, completion: completion)
    }

    @discardableResult
    public func fetch<RequestType: NetworkRequest & NetworkRequestBaseStorable>(
        request: RequestType,
        completion: @escaping (_ timeStamp: Date?, _ result: NetworkStorageResult<RequestType.ResponseType>) -> Void
    ) -> NetworkStorageTask {
        return storagesManager.fetch(request: request, completion: { completion( $0, $1.convert() ) })
    }

    // MARK: Control requests
    public func tasks(filter: NetworkRequestFilter?) -> [NetworkRequestTask] {
        return gatewaysManager.tasks(filter: filter)
    }

    public func containsRequest(filter: NetworkRequestFilter?) -> Bool {
        return gatewaysManager.contains(filter: filter)
    }

    @discardableResult
    public func cancelRequests(filter: NetworkRequestFilter?) -> [NetworkRequestTask] {
        return gatewaysManager.cancel(filter: filter)
    }

    // MARK: Delete in storage
    public func deleteInStorage(request: NetworkRequestBaseStorable) {
        storagesManager.deleteInStorage(request: request)
    }

    public func deleteAllInStorages(withDataClassification dataClassification: AnyHashable) {
        storagesManager.deleteAllInStorages(withDataClassification: dataClassification)
    }

    public func deleteAllInStoragesWithAnyDataClassification() {
        storagesManager.deleteAllInStoragesWithAnyDataClassification()
    }

    public func deleteAllInStorages() {
        storagesManager.deleteAllInStorages()
    }
}
