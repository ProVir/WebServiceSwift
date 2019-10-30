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
    private var lastRequestId: NetworkRequestId = .init(0)

    func generateRequestId() -> NetworkRequestId {
        mutex.lock()
        defer { mutex.unlock() }

        lastRequestId = .init(lastRequestId.value &+ 1)
        return lastRequestId
    }
}

final class GatewaysManager {
    private let gateways: [NetworkBaseGateway]
    private let tasksStorage = TasksStorage()

    private let disableNetworkActivityIndicator: Bool
    private let queueForResponse: DispatchQueue
    private let queueForStorageDefault: DispatchQueue = .global(qos: .utility)

    private lazy var responseExternalHandler: (NetworkBaseRequest, NetworkGatewayResult) -> Void = { _, _ in }

    init(config: NetworkSessionConfiguration) {
        self.gateways = config.gateways
        self.queueForResponse = config.queueForResponse
        self.disableNetworkActivityIndicator = config.disableNetworkActivityIndicator
    }

    func setup(responseExternalHandler: @escaping (NetworkBaseRequest, NetworkGatewayResult) -> Void) {
        self.responseExternalHandler = responseExternalHandler
    }

    deinit {
        let requestList = self.tasksStorage.allTasks()
        let requestListIds = Set(requestList.map { $0.requestId })

        NetworkActivityIndicatorHandler.shared.removeRequests(requestListIds)

        //Cancel all requests for gateways
        let requestsWithGateways = requestList.compactMap { (_, task) -> (NetworkRequestTask.WorkData, NetworkBaseGateway)? in
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

    func makeTask(
        request: NetworkBaseRequest,
        key: NetworkBaseRequestKey?,
        excludeDuplicate: Bool,
        storageDependency: NetworkStorageDependency?,
        canRepeat: Bool,
        completion: @escaping (_ result: NetworkResult<Any>) -> Void
    ) -> NetworkRequestTask {
        let handler: (NetworkRequestTask) -> Void = { [weak self] task in
            self?.perform(task: task, excludeDuplicate: excludeDuplicate, completion: completion)
        }
        return NetworkRequestTask(
            request: request,
            key: key,
            storageDependency: storageDependency,
            canRepeat: canRepeat,
            beginState: .ready,
            performHandler: handler
        )
    }

    func perform(
        request: NetworkBaseRequest,
        key: NetworkBaseRequestKey?,
        excludeDuplicate: Bool,
        storageDependency: NetworkStorageDependency?,
        completion: @escaping (_ result: NetworkResult<Any>) -> Void
    ) -> NetworkRequestTask {
        let task = NetworkRequestTask(
            request: request,
            key: key,
            storageDependency: storageDependency,
            canRepeat: false,
            beginState: .inProgress,
            performHandler: nil
        )
        perform(task: task, excludeDuplicate: excludeDuplicate, completion: completion)
        return task
    }

    func rawDataProcessing(
        request: NetworkRequestBaseStorable,
        rawData: NetworkStorageRawData,
        completion: @escaping (Result<Any, NetworkStorageError>, _ needDelete: Bool) -> Void
    ) {
        guard let (gateway, _) = findGateway(request: request, forDataProcessingFromStorage: type(of: rawData)) else {
            completion(.failure(.notFoundGateway), false)
            return
        }

        let queue = gateway.queueForDataProcessingFromStorage ?? queueForStorageDefault
        queue.async {
            do {
                let response = try gateway.dataProcessingFromStorage(baseRequest: request, rawData: rawData)
                completion(.success(response), false)
            } catch {
                let needDelete = gateway.deleteInvalidRawDataInStorage
                completion(.failure(.failureDataProcessing(error)), needDelete)
            }
        }
    }

    // MARK: Tasks
    func tasks(filter: NetworkRequestFilter?) -> [NetworkRequestTask] {
        return tasksStorage.tasks(filter: filter)
    }

    func contains(filter: NetworkRequestFilter?) -> Bool {
        return tasksStorage.contains(filter: filter)
    }

    func cancel(filter: NetworkRequestFilter?) -> [NetworkRequestTask] {
        let tasks = tasksStorage.tasks(filter: filter)
        tasks.forEach { $0.cancel() }
        return tasks
    }

    // MARK: - Private
    private func perform(task: NetworkRequestTask, excludeDuplicate: Bool, completion: @escaping (_ result: NetworkResult<Any>) -> Void) {
        let request = task.request

        //1. Test duplicate requests
        if excludeDuplicate && tasksStorage.containsDuplicate(task: task) {
            task.setState(.canceled, canceledReason: .duplicate, finishTask: true)
            completion(.canceled(.duplicate))
            return
        }

        //2. Find Gateway and Storage
        guard let (gateway, gatewayIndex) = findGateway(request: request) else {
            task.setState(.failure, canceledReason: nil, finishTask: true)
            completion(.failure(NetworkError.notFoundGateway))
            return
        }

        //3. Request in memory database and perform request (Step #0 -> Step #4)
        let requestId = RequestIdProvider.shared.generateRequestId()

        //Step #3 of 3: Call this closure with result response
        let completionHandlerResponse: (NetworkResult<Any>) -> Void = { [weak self, queueForResponse = self.queueForResponse] result in
            //Usually main thread
            queueForResponse.async {
                if task.isFinished { return }

                self?.removeRequest(requestId: requestId)

                switch result {
                case .success(let data):
                    task.setState(.success, canceledReason: nil, finishTask: true)
                    completion(.success(data))

                case .failure(let error):
                    task.setState(.failure, canceledReason: nil, finishTask: true)
                    completion(.failure(error))

                case .canceled(let reason):
                    task.setState(.canceled, canceledReason: reason, finishTask: true)
                    completion(.canceled(reason))
                }
            }
        }

        //Step #0: Add request to memory database
        task.workData = NetworkRequestTask.WorkData(requestId: requestId, gatewayIndex: gatewayIndex, cancelHandler: { [weak self] neededInGatewayCancel, canceledReason in
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
        let requestHandler = { [responseExternalHandler] in
            gateway.performRequest(
                requestId: requestId,
                baseRequest: request,
                completion: { result in
                    if task.isFinished { return }

                    responseExternalHandler(request, result)
                    switch result {
                    case let .success(responseResult, _): completionHandlerResponse(.success(responseResult))
                    case let .failure(error, _): completionHandlerResponse(.failure(error))
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
    }


    private func findGateway(request: NetworkBaseRequest, forDataProcessingFromStorage rawDataType: NetworkStorageRawData.Type? = nil) -> (NetworkBaseGateway, Int)? {
        for (index, gateway) in self.gateways.enumerated() {
            if gateway.isSupportedRequest(request, forDataProcessingFromStorage: rawDataType) {
                return (gateway, index)
            }
        }

        return nil
    }

    private func addRequest(requestId: NetworkRequestId, task: NetworkRequestTask, gateway: NetworkBaseGateway) {
        if disableNetworkActivityIndicator == false && gateway.useNetworkActivityIndicator {
            NetworkActivityIndicatorHandler.shared.addRequest(requestId)
        }

        tasksStorage.addTask(requestId: requestId, task: task)
    }

    private func removeRequest(requestId: NetworkRequestId) {
        NetworkActivityIndicatorHandler.shared.removeRequest(requestId)

        tasksStorage.removeTask(requestId: requestId)
    }
}
