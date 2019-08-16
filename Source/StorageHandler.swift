//
//  StorageHandler.swift
//  WebServiceSwift 4.0.0
//
//  Created by Vitalii Korotkii on 12/08/2019.
//  Copyright © 2019 ProVir. All rights reserved.
//

import Foundation

final class StorageHandler {

    private let queueForResponse: DispatchQueue
    private let mutex = PThreadMutexLock()
    private let storages: [WebServiceStorage]

    private lazy var rawDataProcessingHandler: (WebServiceRequestBaseStoring, WebServiceStorageRawData, (Result<Any, Error>) -> Void) -> Void
        = { fatalError("Need setup StorageHandler before use") }()

    init(storages: [WebServiceStorage], queueForResponse: DispatchQueue) {
        self.storages = storages
        self.queueForResponse = queueForResponse
    }

    func setup(rawDataProcessingHandler: @escaping (WebServiceRequestBaseStoring, WebServiceStorageRawData, (Result<Any, Error>) -> Void) -> Void) {
        self.rawDataProcessingHandler = rawDataProcessingHandler
    }

    func save(request: WebServiceRequestBaseStoring, rawData: WebServiceStorageRawData?, value: Any) {
        guard let storage = findStorage(request: request) else { return }
        storage.save(request: request, rawData: rawData, value: value)
    }

    func fetch(
        request: WebServiceRequestBaseStoring,
        handler: @escaping (_ timeStamp: Date?, _ response: WebServiceResponse<Any>) -> Void
    ) -> StorageTask {
        let task = StorageTask(request: request)

        guard let storage = findStorage(request: request) else {
            handler(nil, .error(WebServiceRequestError.notFoundStorage))
            task.setStateFromStorage(.error)
            return task
        }

        //1. Wrapped handler
        let completionAsyncHandler = { [queueForResponse] (timeStamp: Date?, response: WebServiceResponse<Any>) in
            queueForResponse.async {
                if task.isCanceled {
                    handler(nil, .canceledRequest(duplicate: task.state == .duplicate))
                    return
                }

                switch response {
                case .data:
                    task.setStateFromStorage(.success)
                case .error:
                    task.setStateFromStorage(.error)
                case .canceledRequest(let duplicate):
                    task.setStateFromStorage(duplicate ? .duplicate : .canceled)
                }

                handler(timeStamp, response)
            }
        }

        //2. Perform read
        storage.fetch(request: request) { [weak self] response in
            guard let self = self, task.isCanceled == false else {
                completionAsyncHandler(nil, .canceledRequest(duplicate: false))
                return
            }

            switch response {
            case let .rawData(rawData, timeStamp):
                self.rawDataProcessingHandler(request, rawData) { result in
                    switch result {
                    case .success(let data): completionAsyncHandler(timeStamp, .data(data))
                    case .failure(let error): completionAsyncHandler(nil, .error(error))
                    }
                }

            case let .value(value, timeStamp):
                completionAsyncHandler(timeStamp, .data(value))

            case let .error(error):
                completionAsyncHandler(nil, .error(error))
            }
        }

        return task
    }

    func deleteInStorage(request: WebServiceRequestBaseStoring) {
        if let storage = findStorage(request: request) {
            storage.delete(request: request)
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
    private func findStorage(request: WebServiceRequestBaseStoring) -> WebServiceStorage? {
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
