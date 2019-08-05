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

class GatewayHandler {
    private struct RequestData {
        let requestId: UInt64
        let gatewayIndex: Int
        let cancelHandler: () -> Void
    }

    private enum RequestState {
        case inWork
        case completed
        case error
        case canceled
    }

    let queueForResponse: DispatchQueue
    let queueForStorageDefault: DispatchQueue = .global(qos: .utility)

    var disableNetworkActivityIndicator = false

    private let mutex = PThreadMutexLock()

    private let gateways: [WebServiceGateway]
    private var requestList: [UInt64: RequestData] = [:] //All requests

    private var requestsForTypes: [String: Set<UInt64>] = [:]        //[Request.Type: [Id]]
    private var requestsForHashs: [AnyHashable: Set<UInt64>] = [:]   //[Request<Hashable>: [Id]]
    private var requestsForKeys:  [AnyHashable: Set<UInt64>] = [:]   //[Key: [Id]]

    init(gateways: [WebServiceGateway],
         queueForResponse: DispatchQueue) {
        self.gateways = gateways
        self.queueForResponse = queueForResponse
    }

    deinit {
        let requestList = mutex.synchronized { self.requestList }
        let requestListIds = Set(requestList.keys)

        NetworkActivityIndicatorHandler.shared.removeRequests(requestListIds)

        //Cancel all requests for gateways
        let requestsWithGateways = requestList.map { (_, value) -> (RequestData, WebServiceGateway) in
            (value, self.gateways[value.gatewayIndex])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [queueForResponse] in
            requestsWithGateways.forEach { (request, gateway) in
                request.cancelHandler()

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
        completionHandler: @escaping (_ response: WebServiceResponse<Any>) -> Void
    ) {

        //1. Depend from previous read storage.
//        weak var readStorageRequestInfo: ReadStorageDependRequestInfo? = readStorageDependNextRequestWait
//        readStorageDependNextRequestWait = nil

        //2. Test duplicate requests
        let requestHashable = request as? AnyHashable

        if excludeDuplicate, let key = key {
            if containsRequest(key: key) {
//                readStorageRequestInfo?.setDuplicate()
                completionHandler(.canceledRequest(duplicate: true))
                return
            }
        } else if excludeDuplicate, let requestHashable = requestHashable {
            if mutex.synchronized({ !(requestsForHashs[requestHashable]?.isEmpty ?? true) }) {
//                readStorageRequestInfo?.setDuplicate()
                completionHandler(.canceledRequest(duplicate: true))
                return
            }
        }

        //3. Find Gateway and Storage
        guard let (gateway, gatewayIndex) = findGateway(request: request) else {
//            readStorageRequestInfo?.setState(.error)
            completionHandler(.error(WebServiceRequestError.notFoundGateway))
            return
        }

//        let storage = internalFindStorage(request: request)

        //4. Request in memory database and perform request (Step #0 -> Step #4)
        let requestType = type(of: request)
        let requestId = GatewayRequestIdProvider.shared.generateRequestId()

        var requestState = RequestState.inWork

        //Step #3: Call this closure with result response
        let completeHandlerResponse: (WebServiceResponse<Any>) -> Void = { [weak self, queueForResponse = self.queueForResponse] response in
            //Usually main thread
            queueForResponse.async {
                guard requestState == .inWork else { return }

                self?.removeRequest(requestId: requestId, key: key, requestHashable: requestHashable, requestType: requestType)

                switch response {
                case .data(let data):
                    requestState = .completed
//                    readStorageRequestInfo?.setState(requestState)
                    completionHandler(.data(data))

                case .error(let error):
                    requestState = .error
//                    readStorageRequestInfo?.setState(requestState)
                    completionHandler(.error(error))

                case .canceledRequest(duplicate: let duplicate):
                    requestState = .canceled
//                    readStorageRequestInfo?.setState(requestState)
                    completionHandler(.canceledRequest(duplicate: duplicate))
                }
            }
        }

        //Step #0: Add request to memory database
        let requestData = RequestData(requestId: requestId, gatewayIndex: gatewayIndex, cancelHandler: {
            completeHandlerResponse(.canceledRequest(duplicate: false))
        })
        addRequest(request: requestData, key: key, requestHashable: requestHashable, requestType: requestType, gateway: gateway)

        //Step #2: Beginer request closure
        let requestHandler = {
            gateway.performRequest(
                requestId: requestId,
                request: request,
                completion: { result in
                    guard requestState == .inWork else { return }

                    switch result {
                    case .success(let response):
//                        storage?.save(request: request, rawData: response.rawDataForStorage, value: response.result)
                        completeHandlerResponse(.data(response.result))

                    case .failure(let error):
                        completeHandlerResponse(.error(error))
                    }
                }
            )
        }

        //Step #1: Call request in queue
        if let queue = gateway.queueForRequest {
            queue.async(execute: requestHandler)
        } else {
            requestHandler()
        }
    }

    // MARK: Contains
    func containsManyRequests() -> Bool {
        return mutex.synchronized { !requestList.isEmpty }
    }

    func containsRequest<RequestType: WebServiceBaseRequesting & Hashable>(_ request: RequestType) -> Bool {
        return mutex.synchronized { !(requestsForHashs[request]?.isEmpty ?? true) }
    }

    func containsRequest(type requestType: WebServiceBaseRequesting.Type) -> Bool {
        return mutex.synchronized { !(requestsForTypes["\(requestType)"]?.isEmpty ?? true) }
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

    private func addRequest(request: RequestData, key: AnyHashable?, requestHashable: AnyHashable?, requestType: WebServiceBaseRequesting.Type, gateway: WebServiceGateway) {
        if disableNetworkActivityIndicator == false && gateway.useNetworkActivityIndicator {
            NetworkActivityIndicatorHandler.shared.addRequest(request.requestId)
        }

        mutex.lock()
        defer { mutex.unlock() }

        requestList[request.requestId] = request
        requestsForTypes["\(requestType)", default: Set<UInt64>()].insert(request.requestId)

        if let key = key {
            requestsForKeys[key, default: Set<UInt64>()].insert(request.requestId)
        }

        if let requestHashable = requestHashable {
            requestsForHashs[requestHashable, default: Set<UInt64>()].insert(request.requestId)
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
                request.cancelHandler()

                let gateway = gateways[request.gatewayIndex]
                let queue = gateway.queueForRequest ?? queueForResponse
                queue.async {
                    gateway.canceledRequest(requestId: request.requestId)
                }
            }
        }
    }
}
