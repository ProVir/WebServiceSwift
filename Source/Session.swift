//
//  Session.swift
//  WebServiceSwift 4.0.0
//
//  Created by Vitalii Korotkii on 02/09/2019.
//  Copyright © 2019 ProVir. All rights reserved.
//

import Foundation

final class Session {
    /// Perform response closures and delegates in dispath queue. Default: main thread.
    public let queueForResponse: DispatchQueue

    /// Ignore gateway parameter ans always don't use networkActivityIndicator in statusBar when requests in process.
    public var disableNetworkActivityIndicator: Bool {
        get { return gatewaysManager.disableNetworkActivityIndicator }
        set { gatewaysManager.disableNetworkActivityIndicator = newValue }
    }

    private let gatewaysManager: GatewaysManager
    private let storagesManager: StoragesManager

    public convenience init(gateways: [Gateway], storages: [Storage], queueForResponse: DispatchQueue = DispatchQueue.main) {
        let gatewaysManager = GatewaysManager(gateways: gateways, queueForResponse: queueForResponse)
        let storagesManager = StoragesManager(storages: storages, queueForResponse: queueForResponse)
        self.init(gatewaysManager: gatewaysManager, storagesManager: storagesManager, queueForResponse: queueForResponse)
    }

    /// Copy with only list gateways, storages and queueForResponse.
    public convenience init(copyConfigurationFrom session: Session) {
        let gatewaysManager = GatewaysManager(copyConfigurationFrom: session.gatewaysManager)
        let storagesManager = StoragesManager(copyConfigurationFrom: session.storagesManager)
        self.init(gatewaysManager: gatewaysManager, storagesManager: storagesManager, queueForResponse: session.queueForResponse)
    }

    init(gatewaysManager: GatewaysManager, storagesManager: StoragesManager, queueForResponse: DispatchQueue) {
        self.gatewaysManager = gatewaysManager
        self.storagesManager = storagesManager
        self.queueForResponse = queueForResponse

        gatewaysManager.setup(saveToStorageHandler: { [weak storagesManager] (request, rawData, value) in
            if let request = request as? RequestBaseStorable {
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
        baseRequest: BaseRequest,
        key: AnyHashable?,
        excludeDuplicate: Bool,
        storageDependency: StorageDependency?,
        completionHandler: @escaping (_ response: Response<Any>) -> Void
    ) -> RequestTask {
        return gatewaysManager.perform(
            request: baseRequest,
            key: key,
            excludeDuplicate: excludeDuplicate,
            storageDependency: storageDependency,
            completionHandler: completionHandler
        )
    }

    @discardableResult
    public func perform<RequestType: Request>(
        request: RequestType,
        key: AnyHashable? = nil,
        excludeDuplicate: Bool = false,
        storageDependency: StorageDependency? = nil,
        completionHandler: @escaping (_ response: Response<RequestType.ResultType>) -> Void
    ) -> RequestTask {
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
    func fetch(baseRequest: RequestBaseStorable, handler: @escaping (_ timeStamp: Date?, _ response: Response<Any>) -> Void) -> StorageTask {
        return storagesManager.fetch(request: baseRequest, handler: handler)
    }

    @discardableResult
    func fetch<RequestType: Request & RequestBaseStorable>(
        request: RequestType,
        handler: @escaping (_ timeStamp: Date?, _ response: Response<RequestType.ResultType>) -> Void
    ) -> StorageTask {
        return storagesManager.fetch(request: request, handler: { handler( $0, $1.convert() ) })
    }

    // MARK: Control requests
    func tasks(filter: RequestFilter?) -> [RequestTask] {
        return gatewaysManager.tasks(filter: filter)
    }

    func containsRequest(filter: RequestFilter?) -> Bool {
        return gatewaysManager.contains(filter: filter)
    }

    @discardableResult
    func cancelRequests(filter: RequestFilter?) -> [RequestTask] {
        return gatewaysManager.cancel(filter: filter)
    }
}
