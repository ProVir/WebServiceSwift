//
//  GatewayHandler.swift
//  WebServiceSwift 4.0.0
//
//  Created by Vitalii Korotkii on 25/07/2019.
//  Copyright © 2019 ProVir. All rights reserved.
//

import Foundation

final class GatewayRequestIdProvider {
    static let shared = GatewayRequestIdProvider()

    private let mutex = PThreadMutexLock()
    private var lastRequestId: UInt64 = 0

    func generateRequestId() -> UInt64 {
        mutex.lock()
        defer { mutex.unlock() }

        lastRequestId = lastRequestId &+ 1
        return lastRequestId
    }
}

final class GatewayHandler {
    let queueForResponse: DispatchQueue
    let queueForStorageDefault: DispatchQueue = .global(qos: .utility)

    var disableNetworkActivityIndicator = false

    private let mutex = PThreadMutexLock()
    private let gateways: [WebServiceGateway]
    private lazy var saveToStorageHandler: (WebServiceBaseRequesting, WebServiceStorageRawData?, _ value: Any) -> Void = { _, _, _ in }

    private var requestList: [UInt64: RequestTask] = [:] //All requests
    private var requestsForTypes: [String: Set<UInt64>] = [:]        //[Request.Type: [Id]]
    private var requestsForHashs: [AnyHashable: Set<UInt64>] = [:]   //[Request<Hashable>: [Id]]
    private var requestsForKeys:  [AnyHashable: Set<UInt64>] = [:]   //[Key: [Id]]

    init(gateways: [WebServiceGateway],
         queueForResponse: DispatchQueue) {
        self.gateways = gateways
        self.queueForResponse = queueForResponse
    }

    func setup(saveToStorageHandler: @escaping (WebServiceBaseRequesting, WebServiceStorageRawData?, _ value: Any) -> Void) {
        self.saveToStorageHandler = saveToStorageHandler
    }

    deinit {
        let requestList = mutex.synchronized { self.requestList }
        let requestListIds = Set(requestList.keys)

        NetworkActivityIndicatorHandler.shared.removeRequests(requestListIds)

        //Cancel all requests for gateways
        let requestsWithGateways = requestList.compactMap { (_, task) -> (RequestTask.WorkData, WebServiceGateway)? in
            guard let request = task.workData else { return nil }
            return (request, self.gateways[request.gatewayIndex])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [queueForResponse] in
            requestsWithGateways.forEach { (request, gateway) in
                request.cancelHandler(false)

                let queue = gateway.queueForRequest ?? queueForResponse
                queue.async {
                    gateway.canceledRequest(requestId: request.requestId)
                }
            }
        }
    }

    func perform(
        request: WebServiceBaseRequesting,
        key: AnyHashable?,
        excludeDuplicate: Bool,
        storageTask: StorageTask?,
        storageDependency: StorageDependency,
        completionHandler: @escaping (_ response: WebServiceResponse<Any>) -> Void
    ) -> RequestTask {
        let task = RequestTask(request: request, key: key, storageTask: storageTask, storageDependency: storageDependency)

        //1. Test duplicate requests
        let requestHashable = request as? AnyHashable

        if excludeDuplicate, let key = key {
            if containsRequest(key: key) {
                task.setState(.duplicate, finishTask: true)
                completionHandler(.canceledRequest(duplicate: true))
                return task
            }
        } else if excludeDuplicate, let requestHashable = requestHashable {
            if mutex.synchronized({ !(requestsForHashs[requestHashable]?.isEmpty ?? true) }) {
                task.setState(.duplicate, finishTask: true)
                completionHandler(.canceledRequest(duplicate: true))
                return task
            }
        }

        //2. Find Gateway and Storage
        guard let (gateway, gatewayIndex) = findGateway(request: request) else {
            task.setState(.error, finishTask: true)
            completionHandler(.error(WebServiceRequestError.notFoundGateway))
            return task
        }

        //3. Request in memory database and perform request (Step #0 -> Step #4)
        let requestType = type(of: request)
        let requestId = GatewayRequestIdProvider.shared.generateRequestId()

        //Step #3 of 3: Call this closure with result response
        let completionHandlerResponse: (WebServiceResponse<Any>) -> Void = { [weak self, queueForResponse = self.queueForResponse] response in
            //Usually main thread
            queueForResponse.async {
                if task.isFinished { return }

                self?.removeRequest(requestId: requestId, key: key, requestHashable: requestHashable, requestType: requestType)

                switch response {
                case .data(let data):
                    task.setState(.success, finishTask: true)
                    completionHandler(.data(data))

                case .error(let error):
                    task.setState(.error, finishTask: true)
                    completionHandler(.error(error))

                case .canceledRequest(duplicate: let duplicate):
                    task.setState(duplicate ? .duplicate : .canceled, finishTask: true)
                    completionHandler(.canceledRequest(duplicate: duplicate))
                }
            }
        }

        //Step #0: Add request to memory database
        task.workData = RequestTask.WorkData(requestId: requestId, gatewayIndex: gatewayIndex, cancelHandler: { [weak self] neededInGatewayCancel in
            completionHandlerResponse(.canceledRequest(duplicate: false))

            if neededInGatewayCancel, let self = self {
                let gateway = self.gateways[gatewayIndex]
                let queue = gateway.queueForRequest ?? self.queueForResponse
                queue.async {
                    gateway.canceledRequest(requestId: requestId)
                }
            }
        })
        addRequest(requestId: requestId, task: task, key: key, requestHashable: requestHashable, requestType: requestType, gateway: gateway)

        //Step #2 of 3: Begin request closure
        let requestHandler = { [saveToStorageHandler] in
            gateway.performRequest(
                requestId: requestId,
                request: request,
                completion: { result in
                    if task.isFinished { return }

                    switch result {
                    case .success(let response):
                        saveToStorageHandler(request, response.rawDataForStorage, response.result)
                        completionHandlerResponse(.data(response.result))

                    case .failure(let error):
                        completionHandlerResponse(.error(error))
                    }
                }
            )
        }

        //Step #1 of 3: Call request in queue
        if let queue = gateway.queueForRequest {
            queue.async(execute: requestHandler)
        } else {
            requestHandler()
        }

        return task
    }

    func rawDataProcessing(request: WebServiceRequestBaseStoring, rawData: WebServiceStorageRawData, completion: @escaping (Result<Any, Error>) -> Void) {
        guard let (gateway, _) = findGateway(request: request, forDataProcessingFromStorage: type(of: rawData)) else {
            completion(.failure(WebServiceRequestError.notFoundGateway))
            return
        }

        let queue = gateway.queueForDataProcessingFromStorage ?? queueForStorageDefault
        queue.async {
            completion(.init { try gateway.dataProcessingFromStorage(request: request, rawData: rawData) })
        }
    }

    // MARK: List
    func allTasks() -> [RequestTask] {
        return mutex.synchronized {
            requestList
                .map { $0.value }
                .sorted { ($0.workData?.requestId ?? 0) < ($1.workData?.requestId ?? 0) }
        }
    }

    // MARK: Contains
    func containsManyRequests() -> Bool {
        return mutex.synchronized { requestList.isEmpty == false }
    }

    func containsRequest<RequestType: WebServiceBaseRequesting & Hashable>(_ request: RequestType) -> Bool {
        return mutex.synchronized { (requestsForHashs[request]?.isEmpty ?? true) == false }
    }

    func containsRequest(type requestType: WebServiceBaseRequesting.Type) -> Bool {
        return mutex.synchronized { (requestsForTypes["\(requestType)"]?.isEmpty ?? true) == false }
    }

    func containsRequest(key: AnyHashable) -> Bool {
        return mutex.synchronized { !(requestsForKeys[key]?.isEmpty ?? true) }
    }

    func containsRequest<K: Hashable>(keyType: K.Type) -> Bool {
        return (listRequests(keyType: keyType, onlyFirst: true)?.count ?? 0) > 0
    }

    // MARK: Cancel
    func cancelAllRequests() {
        let requestList = mutex.synchronized { self.requestList }
        cancelRequests(ids: Set(requestList.keys))
    }

    func cancelRequests<RequestType: WebServiceBaseRequesting & Hashable>(_ request: RequestType) {
        if let list = mutex.synchronized({ requestsForHashs[request] }) {
            cancelRequests(ids: list)
        }
    }

    func cancelRequests(type requestType: WebServiceBaseRequesting.Type) {
        if let list = mutex.synchronized({ requestsForTypes["\(requestType)"] }) {
            cancelRequests(ids: list)
        }
    }

    func cancelRequests(key: AnyHashable) {
        if let list = mutex.synchronized({ requestsForKeys[key] }) {
            cancelRequests(ids: list)
        }
    }

    func cancelRequests<K: Hashable>(keyType: K.Type) {
        if let list = listRequests(keyType: keyType, onlyFirst: false) {
            cancelRequests(ids: list)
        }
    }


    // MARK: - Private
    private func findGateway(request: WebServiceBaseRequesting, forDataProcessingFromStorage rawDataType: WebServiceStorageRawData.Type? = nil) -> (WebServiceGateway, Int)? {
        for (index, gateway) in self.gateways.enumerated() {
            if gateway.isSupportedRequest(request, forDataProcessingFromStorage: rawDataType) {
                return (gateway, index)
            }
        }

        return nil
    }

    private func addRequest(requestId: UInt64, task: RequestTask, key: AnyHashable?, requestHashable: AnyHashable?, requestType: WebServiceBaseRequesting.Type, gateway: WebServiceGateway) {
        if disableNetworkActivityIndicator == false && gateway.useNetworkActivityIndicator {
            NetworkActivityIndicatorHandler.shared.addRequest(requestId)
        }

        mutex.lock()
        defer { mutex.unlock() }

        requestList[requestId] = task
        requestsForTypes["\(requestType)", default: Set<UInt64>()].insert(requestId)

        if let key = key {
            requestsForKeys[key, default: Set<UInt64>()].insert(requestId)
        }

        if let requestHashable = requestHashable {
            requestsForHashs[requestHashable, default: Set<UInt64>()].insert(requestId)
        }
    }

    private func removeRequest(requestId: UInt64, key: AnyHashable?, requestHashable: AnyHashable?, requestType: WebServiceBaseRequesting.Type) {
        NetworkActivityIndicatorHandler.shared.removeRequest(requestId)

        mutex.lock()
        defer { mutex.unlock() }

        requestList.removeValue(forKey: requestId)

        let typeKey = "\(requestType)"
        requestsForTypes[typeKey]?.remove(requestId)
        if requestsForTypes[typeKey]?.isEmpty ?? false { requestsForTypes.removeValue(forKey: typeKey) }

        if let key = key, var ids = requestsForKeys[key] {
            ids.remove(requestId)
            if ids.isEmpty {
                requestsForKeys.removeValue(forKey: key)
            } else {
                requestsForKeys[key] = ids
            }
        }

        if let requestHashable = requestHashable, var ids = requestsForHashs[requestHashable] {
            ids.remove(requestId)
            if ids.isEmpty {
                requestsForHashs.removeValue(forKey: requestHashable)
            } else {
                requestsForHashs[requestHashable] = ids
            }
        }
    }

    private func listRequests<T: Hashable>(keyType: T.Type, onlyFirst: Bool) -> Set<UInt64>? {
        mutex.lock()
        defer { mutex.unlock() }

        var ids = Set<UInt64>()
        for (requestKey, requestIds) in requestsForKeys {
            if requestKey.base is T {
                if onlyFirst {
                    return requestIds
                } else {
                    ids.formUnion(requestIds)
                }
            }
        }

        return ids.isEmpty ? nil : ids
    }

    private func cancelRequests(ids: Set<UInt64>) {
        for requestId in ids {
            if let request = mutex.synchronized({ self.requestList[requestId] }) {
                request.cancel()
            }
        }
    }
}
