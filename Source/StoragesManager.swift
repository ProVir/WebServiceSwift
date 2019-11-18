//
//  StoragesManager.swift
//  WebServiceSwift 4.0.0
//
//  Created by Vitalii Korotkii on 12/08/2019.
//  Copyright © 2019 ProVir. All rights reserved.
//

import Foundation

final class StoragesManager {
    private let storages: [NetworkBaseStorage]
    private let queueForResponse: DispatchQueue

    private lazy var rawDataProcessingHandler: (
        NetworkRequestBaseStorable,
        NetworkStorageRawData,
        @escaping (Result<Any, NetworkStorageError>, _ needDelete: Bool) -> Void
    ) -> Void  = { fatalError("Need setup StorageHandler before use") }()

    init(config: NetworkSessionConfiguration) {
        self.storages = config.storages
        self.queueForResponse = config.queueForResponse
    }

    func setup(rawDataProcessingHandler: @escaping (NetworkRequestBaseStorable, NetworkStorageRawData, @escaping (Result<Any, NetworkStorageError>, _ needDelete: Bool) -> Void) -> Void) {
        self.rawDataProcessingHandler = rawDataProcessingHandler
    }

    func handleResponse(request: NetworkRequestBaseStorable, result: NetworkGatewayResult) {
        switch result {
        case let .success(value, rawData):
            save(request: request, rawData: rawData, value: value)

        case let .failure(_, isContent):
            if isContent, request.storePolicyLevel.shouldDeleteWhenErrorIsContent() {
                deleteInStorage(request: request)
            }
        }
    }

    func makeFetchTask(
        request: NetworkRequestBaseStorable,
        completion: @escaping (_ timeStamp: Date?, _ result: NetworkStorageResult<Any>) -> Void
    ) -> NetworkStorageTask {
        let handler: (NetworkStorageTask) -> Void = { [weak self] task in
            self?.fetch(task: task, completion: completion)
        }
        return NetworkStorageTask(request: request, beginState: .ready, performHandler: handler)
    }

    func fetch(
        request: NetworkRequestBaseStorable,
        completion: @escaping (_ timeStamp: Date?, _ result: NetworkStorageResult<Any>) -> Void
    ) -> NetworkStorageTask {
        let task = NetworkStorageTask(request: request, beginState: .inProgress, performHandler: nil)
        fetch(task: task, completion: completion)
        return task
    }

    func deleteInStorage(request: NetworkRequestBaseStorable) {
        if let storage = findStorage(request: request) {
            storage.delete(baseRequest: request)
        }
    }

    func deleteAllInStorages(withDataClassification dataClassification: AnyHashable) {
        for storage in self.storages {
            let supportClasses = storage.supportDataClassification
            if supportClasses?.contains(dataClassification) ?? false {
                storage.deleteAll()
            }
        }
    }

    func deleteAllInStoragesWithAnyDataClassification() {
        for storage in self.storages {
            let supportClasses = storage.supportDataClassification
            if supportClasses == nil {
                storage.deleteAll()
            }
        }
    }

    func deleteAllInStorages() {
        for storage in self.storages {
            storage.deleteAll()
        }
    }

    // MARK: - Private
    private func fetch(
        task: NetworkStorageTask,
        completion: @escaping (_ timeStamp: Date?, _ result: NetworkStorageResult<Any>) -> Void
    ) {
        let request = task.request

        guard let storage = findStorage(request: request) else {
            completion(nil, .failure(NetworkStorageError.notFoundStorage))
            task.setStateFromStorage(.failure)
            return
        }

        //1. Wrapped handler
        let completionAsyncHandler = { [queueForResponse] (timeStamp: Date?, result: NetworkStorageResult<Any>) in
            queueForResponse.async {
                if task.isCanceled {
                    completion(nil, .canceled(task.storageCanceledReason))
                    return
                }

                switch result {
                case .success: task.setStateFromStorage(.success)
                case .notFound: task.setStateFromStorage(.failure)
                case .failure: task.setStateFromStorage(.failure)
                case .canceled: task.setStateFromStorage(.canceled)
                }

                completion(timeStamp, result)
            }
        }

        //2. Perform read
        storage.fetch(baseRequest: request) { [weak self, weak storage] response in
            guard let self = self, task.isCanceled == false else {
                completionAsyncHandler(nil, .canceled(.unknown))
                return
            }

            switch response {
            case let .rawData(rawData, timeStamp):
                self.rawDataProcessingHandler(request, rawData) { (result, needDelete) in
                    switch result {
                    case .success(let data): completionAsyncHandler(timeStamp, .success(data))
                    case .failure(let error): completionAsyncHandler(nil, .failure(error))
                    }

                    if needDelete {
                        storage?.delete(baseRequest: request)
                    }
                }

            case let .value(value, timeStamp):
                completionAsyncHandler(timeStamp, .success(value))

            case .notFound:
                completionAsyncHandler(nil, .notFound)

            case let .failure(error):
                completionAsyncHandler(nil, .failure(NetworkStorageError.failureFetch(error)))
            }
        }
    }


    private func findStorage(request: NetworkRequestBaseStorable) -> NetworkBaseStorage? {
        let dataClass = request.dataClassificationForStorage
        for storage in self.storages {
            let supportClasses = storage.supportDataClassification
            if (supportClasses?.contains(dataClass) ?? true) && storage.isSupportedRequest(request) {
                return storage
            }
        }

        return nil
    }

    private func save(request: NetworkRequestBaseStorable, rawData: NetworkStorageRawData?, value: Any) {
        guard let storage = findStorage(request: request) else { return }
        storage.save(baseRequest: request, rawData: rawData, value: value) { [weak storage] result in
            if case .failure = result, request.storePolicyLevel.shouldDeleteWhenFailureSave() {
                storage?.delete(baseRequest: request)
            }
        }
    }
}
