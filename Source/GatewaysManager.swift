//
//  GatewaysManager.swift
//  WebServiceSwift 4.0.0
//
//  Created by Vitalii Korotkii on 25/07/2019.
//  Copyright © 2019 ProVir. All rights reserved.
//

import Foundation

final class RequestIdProvider {
    static let shared = RequestIdProvider()

    private let mutex = PThreadMutexLock()
    private var lastRequestId: UInt64 = 0

    func generateRequestId() -> UInt64 {
        mutex.lock()
        defer { mutex.unlock() }

        lastRequestId = lastRequestId &+ 1
        return lastRequestId
    }
}

final class GatewaysManager {
    var disableNetworkActivityIndicator = false

    private let gateways: [Gateway]
    private let tasksStorage = TasksStorage()

    private let queueForResponse: DispatchQueue
    private let queueForStorageDefault: DispatchQueue = .global(qos: .utility)

    private lazy var saveToStorageHandler: (BaseRequest, StorageRawData?, _ value: Any) -> Void = { _, _, _ in }

    init(gateways: [Gateway], queueForResponse: DispatchQueue) {
        self.gateways = gateways
        self.queueForResponse = queueForResponse
    }

    init(copyConfigurationFrom manager: GatewaysManager) {
        self.gateways = manager.gateways
        self.queueForResponse = manager.queueForResponse
        self.disableNetworkActivityIndicator = manager.disableNetworkActivityIndicator
    }

    func setup(saveToStorageHandler: @escaping (BaseRequest, StorageRawData?, _ value: Any) -> Void) {
        self.saveToStorageHandler = saveToStorageHandler
    }

    deinit {
        let requestList = self.tasksStorage.allTasks()
        let requestListIds = Set(requestList.map { $0.requestId })

        NetworkActivityIndicatorHandler.shared.removeRequests(requestListIds)

        //Cancel all requests for gateways
        let requestsWithGateways = requestList.compactMap { (_, task) -> (RequestTask.WorkData, Gateway)? in
            guard let request = task.workData else { return nil }
            return (request, self.gateways[request.gatewayIndex])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [queueForResponse] in
            requestsWithGateways.forEach { (request, gateway) in
                request.cancelHandler(false, .destroyed)

                let queue = gateway.queueForRequest ?? queueForResponse
                queue.async {
                    gateway.canceledRequest(requestId: request.requestId)
                }
            }
        }
    }

    func perform(
        request: BaseRequest,
        key: AnyHashable?,
        excludeDuplicate: Bool,
        storageDependency: StorageDependency?,
        completionHandler: @escaping (_ response: Response<Any>) -> Void
    ) -> RequestTask {
        let task = RequestTask(request: request, key: key, storageDependency: storageDependency)

        //1. Test duplicate requests
        if excludeDuplicate && tasksStorage.containsDuplicate(task: task) {
            task.setState(.canceled, canceledReason: .duplicate, finishTask: true)
            completionHandler(.canceled(.duplicate))
            return task
        }

        //2. Find Gateway and Storage
        guard let (gateway, gatewayIndex) = findGateway(request: request) else {
            task.setState(.failure, canceledReason: nil, finishTask: true)
            completionHandler(.failure(RequestError.notFoundGateway))
            return task
        }

        //3. Request in memory database and perform request (Step #0 -> Step #4)
        let requestId = RequestIdProvider.shared.generateRequestId()

        //Step #3 of 3: Call this closure with result response
        let completionHandlerResponse: (Response<Any>) -> Void = { [weak self, queueForResponse = self.queueForResponse] response in
            //Usually main thread
            queueForResponse.async {
                if task.isFinished { return }

                self?.removeRequest(requestId: requestId)

                switch response {
                case .success(let data):
                    task.setState(.success, canceledReason: nil, finishTask: true)
                    completionHandler(.success(data))

                case .failure(let error):
                    task.setState(.failure, canceledReason: nil, finishTask: true)
                    completionHandler(.failure(error))

                case .canceled(let reason):
                    task.setState(.canceled, canceledReason: reason, finishTask: true)
                    completionHandler(.canceled(reason))
                }
            }
        }

        //Step #0: Add request to memory database
        task.workData = RequestTask.WorkData(requestId: requestId, gatewayIndex: gatewayIndex, cancelHandler: { [weak self] neededInGatewayCancel, canceledReason in
            completionHandlerResponse(.canceled(canceledReason))

            if neededInGatewayCancel, let self = self {
                let gateway = self.gateways[gatewayIndex]
                let queue = gateway.queueForRequest ?? self.queueForResponse
                queue.async {
                    gateway.canceledRequest(requestId: requestId)
                }
            }
        })
        addRequest(requestId: requestId, task: task, gateway: gateway)

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
                        completionHandlerResponse(.success(response.result))

                    case .failure(let error):
                        completionHandlerResponse(.failure(error))
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

    func rawDataProcessing(request: RequestBaseStorable, rawData: StorageRawData, completion: @escaping (Result<Any, Error>) -> Void) {
        guard let (gateway, _) = findGateway(request: request, forDataProcessingFromStorage: type(of: rawData)) else {
            completion(.failure(RequestError.notFoundGateway))
            return
        }

        let queue = gateway.queueForDataProcessingFromStorage ?? queueForStorageDefault
        queue.async {
            completion(.init { try gateway.dataProcessingFromStorage(request: request, rawData: rawData) })
        }
    }

    // MARK: Tasks
    func tasks(filter: RequestFilter?) -> [RequestTask] {
        return tasksStorage.tasks(filter: filter)
    }

    func contains(filter: RequestFilter?) -> Bool {
        return tasksStorage.contains(filter: filter)
    }

    func cancel(filter: RequestFilter?) -> [RequestTask] {
        let tasks = tasksStorage.tasks(filter: filter)
        tasks.forEach { $0.cancel() }
        return tasks
    }

    // MARK: - Private
    private func findGateway(request: BaseRequest, forDataProcessingFromStorage rawDataType: StorageRawData.Type? = nil) -> (Gateway, Int)? {
        for (index, gateway) in self.gateways.enumerated() {
            if gateway.isSupportedRequest(request, forDataProcessingFromStorage: rawDataType) {
                return (gateway, index)
            }
        }

        return nil
    }

    private func addRequest(requestId: UInt64, task: RequestTask, gateway: Gateway) {
        if disableNetworkActivityIndicator == false && gateway.useNetworkActivityIndicator {
            NetworkActivityIndicatorHandler.shared.addRequest(requestId)
        }

        tasksStorage.addTask(requestId: requestId, task: task)
    }

    private func removeRequest(requestId: UInt64) {
        NetworkActivityIndicatorHandler.shared.removeRequest(requestId)

        tasksStorage.removeTask(requestId: requestId)
    }
}
