//
//  Session.swift
//  WebServiceSwift 4.0.0
//
//  Created by Vitalii Korotkii on 02/09/2019.
//  Copyright © 2019 ProVir. All rights reserved.
//

import Foundation

public struct NetworkSessionConfiguration {
    public var gateways: [NetworkGateway]
    public var storages: [NetworkStorage]

    /// Perform response closures and delegates in dispath queue. Default: main thread.
    public var queueForResponse: DispatchQueue

    /// Ignore gateway parameter and always don't use networkActivityIndicator in statusBar when requests in process.
    public var disableNetworkActivityIndicator: Bool

    public init(gateways: [NetworkGateway],
                storages: [NetworkStorage],
                queueForResponse: DispatchQueue = .main,
                disableNetworkActivityIndicator: Bool = false) {
        self.gateways = gateways
        self.storages = storages
        self.queueForResponse = queueForResponse
        self.disableNetworkActivityIndicator = disableNetworkActivityIndicator
    }
}

final class NetworkSession {
    private let gatewaysManager: GatewaysManager
    private let storagesManager: StoragesManager

    public init(_ config: NetworkSessionConfiguration) {
        self.gatewaysManager = GatewaysManager(config: config)
        self.storagesManager = StoragesManager(config: config)

        gatewaysManager.setup(saveToStorageHandler: { [weak storagesManager] (request, rawData, value) in
            if let request = request as? NetworkRequestBaseStorable {
                storagesManager?.save(request: request, rawData: rawData, value: value)
            }
        })
        storagesManager.setup(rawDataProcessingHandler: { [weak gatewaysManager] (request, rawData, completion) in
            gatewaysManager?.rawDataProcessing(request: request, rawData: rawData, completion: completion)
        })
    }

    // MARK: Perform requests
    @discardableResult
    public func perform(
        baseRequest: NetworkBaseRequest,
        key: NetworkBaseRequestKey?,
        excludeDuplicate: Bool,
        storageDependency: NetworkStorageDependency?,
        completionHandler: @escaping (_ response: NetworkResponse<Any>) -> Void
    ) -> NetworkRequestTask {
        return gatewaysManager.perform(
            request: baseRequest,
            key: key,
            excludeDuplicate: excludeDuplicate,
            storageDependency: storageDependency,
            completionHandler: completionHandler
        )
    }

    @discardableResult
    public func perform<RequestType: NetworkRequest>(
        request: RequestType,
        key: NetworkBaseRequestKey? = nil,
        excludeDuplicate: Bool = false,
        storageDependency: NetworkStorageDependency? = nil,
        completionHandler: @escaping (_ response: NetworkResponse<RequestType.ResultType>) -> Void
    ) -> NetworkRequestTask {
        return gatewaysManager.perform(
            request: request,
            key: key,
            excludeDuplicate: excludeDuplicate,
            storageDependency: storageDependency,
            completionHandler: { completionHandler( $0.convert() ) }
        )
    }

    // MARK: Read storage
    @discardableResult
    func fetch(baseRequest: NetworkRequestBaseStorable, handler: @escaping (_ timeStamp: Date?, _ response: NetworkResponse<Any>) -> Void) -> NetworkStorageTask {
        return storagesManager.fetch(request: baseRequest, handler: handler)
    }

    @discardableResult
    func fetch<RequestType: NetworkRequest & NetworkRequestBaseStorable>(
        request: RequestType,
        handler: @escaping (_ timeStamp: Date?, _ response: NetworkResponse<RequestType.ResultType>) -> Void
    ) -> NetworkStorageTask {
        return storagesManager.fetch(request: request, handler: { handler( $0, $1.convert() ) })
    }

    // MARK: Control requests
    func tasks(filter: NetworkRequestFilter?) -> [NetworkRequestTask] {
        return gatewaysManager.tasks(filter: filter)
    }

    func containsRequest(filter: NetworkRequestFilter?) -> Bool {
        return gatewaysManager.contains(filter: filter)
    }

    @discardableResult
    func cancelRequests(filter: NetworkRequestFilter?) -> [NetworkRequestTask] {
        return gatewaysManager.cancel(filter: filter)
    }
}
