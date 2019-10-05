//
//  StoragesManager.swift
//  WebServiceSwift 4.0.0
//
//  Created by Vitalii Korotkii on 12/08/2019.
//  Copyright © 2019 ProVir. All rights reserved.
//

import Foundation

final class StoragesManager {
    private let mutex = PThreadMutexLock()
    private let storages: [NetworkBaseStorage]
    private let queueForResponse: DispatchQueue

    private lazy var rawDataProcessingHandler: (NetworkRequestBaseStorable, NetworkStorageRawData, @escaping (Result<Any, NetworkStorageError>) -> Void) -> Void
        = { fatalError("Need setup StorageHandler before use") }()

    init(config: NetworkSessionConfiguration) {
        self.storages = config.storages
        self.queueForResponse = config.queueForResponse
    }

    func setup(rawDataProcessingHandler: @escaping (NetworkRequestBaseStorable, NetworkStorageRawData, @escaping (Result<Any, NetworkStorageError>) -> Void) -> Void) {
        self.rawDataProcessingHandler = rawDataProcessingHandler
    }

    func save(request: NetworkRequestBaseStorable, rawData: NetworkStorageRawData?, value: Any) {
        guard let storage = findStorage(request: request) else { return }
        storage.save(baseRequest: request, rawData: rawData, value: value) { [weak storage] result in
            if case .failure(let error) = result, request.shouldDeleteInStorageWhenSaveFailure(error) {
                storage?.delete(baseRequest: request)
            }
        }
    }

    func fetch(
        request: NetworkRequestBaseStorable,
        completion: @escaping (_ timeStamp: Date?, _ response: NetworkStorageResponse<Any>) -> Void
    ) -> NetworkStorageTask {
        let task = NetworkStorageTask(request: request)

        guard let storage = findStorage(request: request) else {
            completion(nil, .failure(NetworkStorageError.notFoundStorage))
            task.setStateFromStorage(.failure)
            return task
        }

        //1. Wrapped handler
        let completionAsyncHandler = { [queueForResponse] (timeStamp: Date?, response: NetworkStorageResponse<Any>) in
            queueForResponse.async {
                if task.isCanceled {
                    completion(nil, .canceled(task.storageCanceledReason))
                    return
                }

                switch response {
                case .success: task.setStateFromStorage(.success)
                case .notFound: task.setStateFromStorage(.failure)
                case .failure: task.setStateFromStorage(.failure)
                case .canceled: task.setStateFromStorage(.canceled)
                }

                completion(timeStamp, response)
            }
        }

        //2. Perform read
        storage.fetch(baseRequest: request) { [weak self] response in
            guard let self = self, task.isCanceled == false else {
                completionAsyncHandler(nil, .canceled(.unknown))
                return
            }

            switch response {
            case let .rawData(rawData, timeStamp):
                self.rawDataProcessingHandler(request, rawData) { result in
                    switch result {
                    case .success(let data): completionAsyncHandler(timeStamp, .success(data))
                    case .failure(let error): completionAsyncHandler(nil, .failure(error))
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
}
