//
//  WebService.swift
//  WebServiceSwift 3.0.0
//
//  Created by Короткий Виталий (ViR) on 14.06.2017.
//  Updated to 3.0.0 by Короткий Виталий (ViR) on 04.09.2018.
//  Copyright © 2017 - 2018 ProVir. All rights reserved.
//

import Foundation

#if os(iOS)
import UIKit
#endif


/// Controller for work. All requests are performed through it.
public class WebService {
    
    /// Dependency type to next request (`performRequest()`). Use only to read from storage.
    public enum ReadStorageDependencyType {
        /// Not depend for next request
        case notDepend
        
        /// Ignore result from storage only after success response
        case dependSuccessResult
        
        /// As dependSuccessResult, but canceled read from storage after duplicated or canceled next request.
        case dependFull
    }
    
    /// Perform response closures and delegates in dispath queue. Default: main thread.
    public let queueForResponse: DispatchQueue
    
    /// Ignore endpoint parameter ans always don't use networkActivityIndicator in statusBar when requests in process.
    public var disableNetworkActivityIndicator = false
    
    
    /**
     Constructor for WebService.
     
     - Parameters:
        - endpoints: All sorted endpoints that support all requests.
        - storages: All sorted storages that support all requests.
        - queueForResponse: Dispatch Queue for results response. Thread for public method call and queueForResponse recommended be equal. Default: main thread.
     */
    public init(endpoints: [WebServiceEndpoint],
                storages: [WebServiceStorage],
                queueForResponse: DispatchQueue = DispatchQueue.main) {
        
        self.endpoints = endpoints
        self.storages = storages
        
        self.queueForResponse = queueForResponse
    }
    
    deinit {
        let requestList = mutex.synchronized({ self.requestList })
        let requestListIds = Set(requestList.keys)
        
        //End networkActivityIndicator for all requests
        WebService.staticMutex.synchronized {
            WebService.networkActivityIndicatorRequestIds.subtract(requestListIds)
        }
        
        //Cancel all requests for endpoint
        let queue = queueForResponse
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for (_, requestData) in requestList {
                requestData.cancel(queueForResponse: queue)
            }
        }
    }
    
    /// Clone WebService with only list endpoints, storages and queueForResponse.
    public func clone() -> WebService {
        return WebService(endpoints: endpoints, storages: storages, queueForResponse: queueForResponse)
    }
    
    
    //MARK: Private data
    private static var staticMutex = PThreadMutexLock()
    private var mutex = PThreadMutexLock()
    
    private static var networkActivityIndicatorRequestIds = Set<UInt64>() {
        didSet {
            #if os(iOS)
            let isVisible = !networkActivityIndicatorRequestIds.isEmpty
            DispatchQueue.main.async { UIApplication.shared.isNetworkActivityIndicatorVisible = isVisible }
            #endif
        }
    }
    
    private let endpoints: [WebServiceEndpoint]
    private let storages: [WebServiceStorage]
    
    private var requestList: [UInt64: RequestData] = [:] //All requests
    
    private var requestsForTypes: [String: Set<UInt64>] = [:]        //[Request.Type: [Id]]
    private var requestsForHashs: [AnyHashable: Set<UInt64>] = [:]   //[Request<Hashable>: [Id]]
    private var requestsForKeys:  [AnyHashable: Set<UInt64>] = [:]   //[Key: [Id]]
    
    private weak var readStorageDependNextRequestWait: ReadStorageDependRequestInfo?
    
    
    // MARK: Perform requests
    
    /**
     Request to server (endpoint). Response result in closure.
     
     - Parameters:
        - request: The request with data and result type.
        - completionHandler: Closure for response result from server.
     */
    public func performRequest<RequestType: WebServiceRequesting>(_ request: RequestType, completionHandler: @escaping (_ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        performBaseRequest(request, key: nil, excludeDuplicate: false, completionHandler: { completionHandler( $0.convert() ) })
    }
    
    /**
     Request to server (endpoint). Response result in closure.
     
     - Parameters:
        - request: The request with data and result type.
        - key: unique key for controling requests - contains and canceled. Also use for excludeDuplicate.
        - excludeDuplicate: Exclude duplicate requests. Requests are equal if their keys match.
        - completionHandler: Closure for response result from server.
     */
    public func performRequest<RequestType: WebServiceRequesting>(_ request: RequestType, key: AnyHashable, excludeDuplicate: Bool, completionHandler: @escaping (_ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        performBaseRequest(request, key: key, excludeDuplicate: excludeDuplicate, completionHandler: { completionHandler( $0.convert() ) })
    }
    
    /**
     Request to server (endpoint). Response result in closure.
     
     - Parameters:
        - request: The hashable (also equatable) request with data and result type.
        - excludeDuplicate: Exclude duplicate equatable requests.
        - completionHandler: Closure for response result from server.
     */
    public func performRequest<RequestType: WebServiceRequesting & Hashable>(_ request: RequestType, excludeDuplicate: Bool, completionHandler: @escaping (_ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        performBaseRequest(request, key: nil, excludeDuplicate: excludeDuplicate, completionHandler: { completionHandler( $0.convert() ) })
    }
    
    /**
     Request without support generic for server (endpoint). Response result in closure.
     
     - Parameters:
        - request: The request with data.
        - key: Unique key for controling requests - contains and canceled. Also use for excludeDuplicate. Default: nil.
        - excludeDuplicate: Exclude duplicate requests. Equal requests alogorithm: test for key if not null, else test requests equal if request is hashable.
        - completionHandler: Closure for response result from server.
     */
    public func performBaseRequest(_ request: WebServiceBaseRequesting,
                                   key: AnyHashable? = nil,
                                   excludeDuplicate: Bool = false,
                                   completionHandler: @escaping (_ response: WebServiceAnyResponse) -> Void) {
        
        //1. Depend from previous read storage.
        weak var readStorageRequestInfo: ReadStorageDependRequestInfo? = readStorageDependNextRequestWait
        readStorageDependNextRequestWait = nil
        
        //2. Test duplicate requests
        let requestHashable = request as? AnyHashable
        
        if excludeDuplicate, let key = key {
            if containsRequest(key: key) {
                readStorageRequestInfo?.setDuplicate()
                completionHandler(.canceledRequest(duplicate: true))
                return
            }
        } else if excludeDuplicate, let requestHashable = requestHashable {
            if mutex.synchronized({ !(requestsForHashs[requestHashable]?.isEmpty ?? true) }) {
                readStorageRequestInfo?.setDuplicate()
                completionHandler(.canceledRequest(duplicate: true))
                return
            }
        }
        
        //3. Find Endpoint and Storage
        guard let endpoint = internalFindEndpoint(request: request) else {
            readStorageRequestInfo?.setState(.error)
            completionHandler(.error(WebServiceRequestError.notFoundEndpoint))
            return
        }
        
        let storage = internalFindStorage(request: request)
        
        //4. Request in memory database and Perform request (Step #0 -> Step #4)
        let requestType = type(of: request)
        let requestId = internalNewRequestId()
 
        var requestState = RequestState.inWork
        
        //Step #4: Call this closure with result response
        let completeHandlerResponse: (WebServiceAnyResponse) -> Void = { [weak self, queueForResponse = self.queueForResponse] response in
            //Usually main thread
            queueForResponse.async {
                guard requestState == .inWork else { return }
                
                self?.internalRemoveRequest(requestId: requestId, key: key, requestHashable: requestHashable, requestType: requestType)
                
                switch response {
                case .data(let data):
                    requestState = .completed
                    readStorageRequestInfo?.setState(requestState)
                    completionHandler(.data(data))
                    
                case .error(let error):
                    requestState = .error
                    readStorageRequestInfo?.setState(requestState)
                    completionHandler(.error(error))
                    
                case .canceledRequest(duplicate: let duplicate):
                    requestState = .canceled
                    readStorageRequestInfo?.setState(requestState)
                    completionHandler(.canceledRequest(duplicate: duplicate))
                }
            }
        }
        
        //Step #0: Add request to memory database
        internalAddRequest(requestId: requestId, key: key, requestHashable: requestHashable, requestType: requestType, endpoint: endpoint, cancelHandler: {
            //Canceled request
            completeHandlerResponse(.canceledRequest(duplicate: false))
        })
        
        
        //Step #3: Data handler closure for raw data from server
        let dataHandler: (Any) -> Void = { (data) in
            do {
                let resultData = try endpoint.dataProcessing(request: request,
                                                             rawData: data,
                                                             fromStorage: false)
                
                storage?.writeData(request: request, data: data, isRaw: true)
                storage?.writeData(request: request, data: resultData, isRaw: false)
                
                completeHandlerResponse(.data(resultData))
                
            } catch {
                completeHandlerResponse(.error(error))
            }
        }
        
        //Step #2: Beginer request closure
        let requestHandler = {
            endpoint.performRequest(requestId: requestId,
                                    request: request,
                                    completionWithRawData: { data in
                                    
                                    //Raw data from server
                                    guard requestState == .inWork else { return }
                                    
                                    if let queue = endpoint.queueForDataProcessing {
                                        queue.async { dataHandler(data) }
                                    } else {
                                        dataHandler(data)
                                    }
                                    
            },
                                  completionWithError: { error in
                                    //Error request
                                    completeHandlerResponse(.error(error))
            })
        }
        
        //Step #1: Call request in queue
        if let queue = endpoint.queueForRequest {
            queue.async(execute: requestHandler)
        } else {
            requestHandler()
        }
    }
    
    
    //MARK: Read from storage
    
    /**
     Read last success data from storage. Response result in closure.
     
     - Parameters:
         - request: The request with data.
         - dependencyNextRequest: Type dependency from next performRequest.
         - completionHandler: Closure for read data from storage.
         - timeStamp: TimeStamp when saved from server (endpoint).
         - response: Result read from storage.
     */
    public func readStorage<RequestType: WebServiceRequesting>(_ request: RequestType, dependencyNextRequest: ReadStorageDependencyType = .notDepend, completionHandler: @escaping (_ timeStamp: Date?, _ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        if let storage = internalFindStorage(request: request) {
            //CompletionResponse
            let completionHandlerInternal:(_ timeStamp: Date?, _ response: WebServiceAnyResponse) -> Void = { completionHandler($0, $1.convert()) }
            
            //Request
            internalReadStorage(storage: storage, request: request, dependencyNextRequest: dependencyNextRequest, completionHandler: completionHandlerInternal)
            
        } else {
            completionHandler(nil, .error(WebServiceRequestError.notFoundStorage))
        }
    }
    
    /**
     Read last success data from storage without information result type data. Response result in closure.
     
     - Parameters:
        - request: The request with data.
        - dependencyNextRequest: Type dependency from next performRequest.
        - completionHandler: Closure for read data from storage.
        - timeStamp: TimeStamp when saved from server (endpoint).
        - response: Result read from storage.
     */
    public func readStorageAnyData(_ request: WebServiceBaseRequesting,
                                   dependencyNextRequest: ReadStorageDependencyType = .notDepend,
                                   completionHandler: @escaping (_ timeStamp: Date?, _ response: WebServiceAnyResponse) -> Void) {
        if let storage = internalFindStorage(request: request) {
            internalReadStorage(storage: storage, request: request, dependencyNextRequest: dependencyNextRequest, completionHandler: completionHandler)
        } else {
            completionHandler(nil, .error(WebServiceRequestError.notFoundStorage))
        }
    }
    
    
    // MARK: Perform requests use delegate for response
    
    /**
     Request to server (endpoint). Response result send to delegate.
     
     - Parameters:
        - request: The request with data.
        - responseDelegate: Weak delegate for response from this request.
     */
    public func performRequest(_ request: WebServiceBaseRequesting, responseDelegate: WebServiceDelegate?) {
        internalPerformRequest(request, key: nil, excludeDuplicate: false, responseDelegate: responseDelegate)
    }
    
    /**
     Request to server (endpoint). Response result send to delegate.
     
     - Parameters:
         - request: The request with data.
         - key: unique key for controling requests - contains and canceled. Also use for excludeDuplicate.
         - excludeDuplicate: Exclude duplicate requests. Requests are equal if their keys match.
         - responseDelegate: Weak delegate for response from this request.
     */
    public func performRequest(_ request: WebServiceBaseRequesting, key: AnyHashable, excludeDuplicate: Bool, responseDelegate: WebServiceDelegate?) {
        internalPerformRequest(request, key: key, excludeDuplicate: excludeDuplicate, responseDelegate: responseDelegate)
    }
    
    /**
     Request to server (endpoint). Response result send to delegate.
     
     - Parameters:
         - request: The hashable (also equatable) request with data.
         - excludeDuplicate: Exclude duplicate equatable requests.
         - responseDelegate: Weak delegate for response from this request.
     */
    public func performRequest<RequestType: WebServiceBaseRequesting & Hashable>(_ request: RequestType, excludeDuplicate: Bool, responseDelegate: WebServiceDelegate?) {
        internalPerformRequest(request, key: nil, excludeDuplicate: excludeDuplicate, responseDelegate: responseDelegate)
    }
    
    /**
     Read last success data from storage. Response result send to delegate.
     
     - Parameters:
         - request: The request with data.
         - key: unique key for controling requests, use only for response delegate.
         - dependencyNextRequest: Type dependency from next performRequest.
         - responseOnlyData: When `true` - response result send to delegate only if have data. Default false.
         - responseDelegate: Weak delegate for response from this request.
     */
    public func readStorage(_ request: WebServiceBaseRequesting, key: AnyHashable? = nil, dependencyNextRequest: ReadStorageDependencyType = .notDepend, responseOnlyData: Bool = false, responseDelegate delegate: WebServiceDelegate) {
        readStorageAnyData(request, dependencyNextRequest: dependencyNextRequest) { [weak delegate] _, response in
            if responseOnlyData == false { }
            else if case .data = response { }
            else { return }
            
            if let delegate = delegate {
                delegate.webServiceResponse(request: request, key: key, isStorageRequest: true, response: response)
            }
        }
    }
    
    
    // MARK: Contains requests
    
    /// Returns a Boolean value indicating whether the current queue contains many requests.
    public func containsManyRequests() -> Bool {
        return mutex.synchronized { !requestList.isEmpty }
    }
    
    /**
     Returns a Boolean value indicating whether the current queue contains the given request.
     
     - Parameter request: The request to find in the current queue.
     - Returns: `true` if the request was found in the current queue; otherwise, `false`.
     */
    public func containsRequest<RequestType: WebServiceBaseRequesting & Hashable>(_ request: RequestType) -> Bool {
        return mutex.synchronized { !(requestsForHashs[request]?.isEmpty ?? true) }
    }
    
    /**
     Returns a Boolean value indicating whether the current queue contains requests the given type.
     
     - Parameter requestType: The type request to find in the all current queue.
     - Returns: `true` if one request with WebServiceBaseRequesting.Type was found in the current queue; otherwise, `false`.
     */
    public func containsRequest(type requestType: WebServiceBaseRequesting.Type) -> Bool {
        return mutex.synchronized { !(requestsForTypes["\(requestType)"]?.isEmpty ?? true) }
    }
    
    /**
     Returns a Boolean value indicating whether the current queue contains the given request with key.
     
     - Parameter key: The key to find requests in the current queue.
     - Returns: `true` if the request with key was found in the current queue; otherwise, `false`.
     */
    public func containsRequest(key: AnyHashable) -> Bool {
        return mutex.synchronized { !(requestsForKeys[key]?.isEmpty ?? true) }
    }
    
    /**
     Returns a Boolean value indicating whether the current queue contains requests the given type key.
     
     - Parameter keyType: The type requestKey to find in the all current queue.
     - Returns: `true` if one request with key.Type was found in the current queue; otherwise, `false`.
     */
    public func containsRequest<K: Hashable>(keyType: K.Type) -> Bool {
        return (internalListRequest(keyType: keyType, onlyFirst: true)?.count ?? 0) > 0
    }

    
    //MARK: Cancel requests
    
    /// Cancel all requests in current queue.
    public func cancelAllRequests() {
        let requestList = mutex.synchronized { self.requestList }
        internalCancelRequests(ids: Set(requestList.keys))
    }
    
    /**
     Cancel all requests with equal this request.
     
     - Parameter request: The request to find in the current queue.
     */
    public func cancelRequests<RequestType: WebServiceBaseRequesting & Hashable>(_ request: RequestType) {
        if let list = mutex.synchronized({ requestsForHashs[request] }) {
            internalCancelRequests(ids: list)
        }
    }
    
    /**
     Cancel all requests for request type.

     - Parameter requestType: The WebServiceBaseRequesting.Type to find in the current queue.
     */
    public func cancelRequests(type requestType: WebServiceBaseRequesting.Type) {
        if let list = mutex.synchronized({ requestsForTypes["\(requestType)"] }) {
            internalCancelRequests(ids: list)
        }
    }
    
    /**
     Cancel all requests with key.

     - Parameter key: The key to find in the current queue.
     */
    public func cancelRequests(key: AnyHashable) {
        if let list = mutex.synchronized({ requestsForKeys[key] }) {
            internalCancelRequests(ids: list)
        }
    }
    
    /**
     Cancel all requests with key.Type.
     
     - Parameter keyType: The key.Type to find in the current queue.
     */
    public func cancelRequests<K: Hashable>(keyType: K.Type) {
        if let list = internalListRequest(keyType: keyType, onlyFirst: false) {
            internalCancelRequests(ids: list)
        }
    }
    
    
    //MARK: Delete data in Storages
    
    /**
     Delete data in storage for concrete request.
     
     - Parameter request: Original request.
     */
    public func deleteInStorage(request: WebServiceBaseRequesting) {
        if let storage = internalFindStorage(request: request) {
            storage.deleteData(request: request)
        }
    }
    
    /**
     Delete all data in storages. Used only storages with support concrete data classification.
     
     - Parameter with: Data Classification for find all storages.
     */
    public func deleteAllInStorages(withDataClassification dataClassification: AnyHashable) {
        for storage in self.storages {
            let supportClasses = storage.supportDataClassification
            
            if supportClasses.contains(dataClassification) {
                storage.deleteAllData()
            }
        }
    }
    
    /**
     Delete all data in storages. Used only storages with support any data classification.
     */
    public func deleteAllInStoragesWithAnyDataClassification() {
        for storage in self.storages {
            let supportClasses = storage.supportDataClassification
            
            if supportClasses.isEmpty {
                storage.deleteAllData()
            }
        }
    }
    
    /**
     Delete all data in all storages.
     */
    public func deleteAllInStorages() {
        for storage in self.storages {
            storage.deleteAllData()
        }
    }
    
    
    //MARK: - Private functions
    private func internalPerformRequest(_ request: WebServiceBaseRequesting, key: AnyHashable?, excludeDuplicate: Bool, responseDelegate delegate: WebServiceDelegate?) {
        performBaseRequest(request, key: key, excludeDuplicate: excludeDuplicate) { [weak delegate] response in
            if let delegate = delegate {
                delegate.webServiceResponse(request: request, key: key, isStorageRequest: false, response: response)
            }
        }
    }
    
    private func internalReadStorage(storage: WebServiceStorage, request: WebServiceBaseRequesting, dependencyNextRequest: ReadStorageDependencyType, completionHandler handler: @escaping (_ timeStamp: Date?, _ response: WebServiceAnyResponse) -> Void) {
        let nextRequestInfo: ReadStorageDependRequestInfo?
        let completionHandler: (_ timeStamp: Date?, _ response: WebServiceAnyResponse) -> Void
        
        //1. Dependency setup
        if dependencyNextRequest == .notDepend {
            nextRequestInfo = nil
            completionHandler = handler
            
        } else {
            nextRequestInfo = ReadStorageDependRequestInfo(dependencyType: dependencyNextRequest)
            readStorageDependNextRequestWait = nextRequestInfo
            
            completionHandler = { [weak self] timeStamp, response in
                if self?.readStorageDependNextRequestWait === nextRequestInfo {
                    self?.readStorageDependNextRequestWait = nil
                }
                
                if nextRequestInfo?.canRead() ?? true {
                    handler(timeStamp, response)
                } else if nextRequestInfo?.isDuplicate ?? false {
                    handler(timeStamp, .canceledRequest(duplicate: true))
                } else {
                    handler(timeStamp, .canceledRequest(duplicate: false))
                }
            }
        }
        
        //2. Perform read
        do {
            try storage.readData(request: request) { [weak self, queueForResponse = self.queueForResponse] isRawData, timeStamp, response in
                if (nextRequestInfo?.canRead() ?? true) == false {
                    self?.queueForResponse.async {
                        completionHandler(nil, .canceledRequest(duplicate: false))
                    }
                    
                } else if isRawData, let rawData = response.dataResponse() {
                    if let endpoint = self?.internalFindEndpoint(request: request, rawDataTypeForRestoreFromStorage: type(of: rawData)) {
                        //Handler closure with fined endpoint for use next
                        let handler = {
                            do {
                                let data = try endpoint.dataProcessing(request: request, rawData: rawData, fromStorage: true)
                                
                                queueForResponse.async {
                                    completionHandler(timeStamp, .data(data))
                                }
                            } catch {
                                queueForResponse.async {
                                    completionHandler(nil, .error(error))
                                }
                            }
                        }
                        
                        //Call handler
                        if let queue = endpoint.queueForDataProcessingFromStorage {
                            queue.async(execute: handler)
                        } else {
                            handler()
                        }
                        
                    } else {
                        //Not found endpoint
                        queueForResponse.async {
                            completionHandler(nil, .error(WebServiceRequestError.notFoundEndpoint))
                        }
                    }
                    
                } else {
                    //No RAW data
                    self?.queueForResponse.async {
                        completionHandler(timeStamp, response)
                    }
                }
            }
        } catch {
            self.queueForResponse.async {
                completionHandler(nil, .error(error))
            }
        }
    }
    
    
    // MARK: Find endpoints and storages
    private func internalFindEndpoint(request: WebServiceBaseRequesting, rawDataTypeForRestoreFromStorage: Any.Type? = nil) -> WebServiceEndpoint? {
        for endpoint in self.endpoints {
            if endpoint.isSupportedRequest(request, rawDataTypeForRestoreFromStorage: rawDataTypeForRestoreFromStorage) {
                return endpoint
            }
        }
        
        return nil
    }
    
    private func internalFindStorage(request: WebServiceBaseRequesting) -> WebServiceStorage? {
        let dataClass: AnyHashable
        if let request = request as? WebServiceRequestBaseStoring {
            dataClass = request.dataClassificationForStorage
        } else {
            dataClass = WebServiceDefaultDataClassification
        }
        
        for storage in self.storages {
            let supportClasses = storage.supportDataClassification
            
            if (supportClasses.isEmpty || supportClasses.contains(dataClass))
                && storage.isSupportedRequest(request) {
                return storage
            }
        }
        
        return nil
    }
    
    
    // MARK: Request Ids
    private static var lastRequestId: UInt64 = 0
    private func internalNewRequestId() -> UInt64 {
        WebService.staticMutex.lock()
        defer { WebService.staticMutex.unlock() }
        
        WebService.lastRequestId = WebService.lastRequestId &+ 1
        return WebService.lastRequestId
    }
    
    private func internalAddRequest(requestId: UInt64, key: AnyHashable?, requestHashable: AnyHashable?, requestType: WebServiceBaseRequesting.Type, endpoint: WebServiceEndpoint, cancelHandler: @escaping ()->Void) {
        //Increment counts for visible NetworkActivityIndicator in StatusBar if need only for iOS
        #if os(iOS)
        if !disableNetworkActivityIndicator && endpoint.useNetworkActivityIndicator {
            WebService.staticMutex.lock()
            WebService.networkActivityIndicatorRequestIds.insert(requestId)
            WebService.staticMutex.unlock()
        }
        #endif
        
        //Thread safe
        mutex.lock()
        defer { mutex.unlock() }
        
        requestList[requestId] = RequestData(requestId: requestId, endpoint: endpoint, cancelHandler: cancelHandler)
        requestsForTypes["\(requestType)", default: Set<UInt64>()].insert(requestId)
        
        if let key = key {
            requestsForKeys[key, default: Set<UInt64>()].insert(requestId)
        }
        
        if let requestHashable = requestHashable {
            requestsForHashs[requestHashable, default: Set<UInt64>()].insert(requestId)
        }
    }
    
    private func internalRemoveRequest(requestId: UInt64, key: AnyHashable?, requestHashable: AnyHashable?, requestType: WebServiceBaseRequesting.Type) {
        WebService.staticMutex.lock()
        WebService.networkActivityIndicatorRequestIds.remove(requestId)
        WebService.staticMutex.unlock()
        
        //Thread safe
        mutex.lock()
        defer { mutex.unlock() }

        requestList.removeValue(forKey: requestId)
        
        let typeKey = "\(requestType)"
        requestsForTypes[typeKey]?.remove(requestId)
        if requestsForTypes[typeKey]?.isEmpty ?? false { requestsForTypes.removeValue(forKey: typeKey) }
        
        if let key = key {
            requestsForKeys[key]?.remove(requestId)
            if requestsForKeys[key]?.isEmpty ?? false { requestsForKeys.removeValue(forKey: key) }
        }
  
        if let requestHashable = requestHashable {
            requestsForHashs[requestHashable]?.remove(requestId)
            if requestsForHashs[requestHashable]?.isEmpty ?? false { requestsForHashs.removeValue(forKey: requestHashable) }
        }
    }
    
    private func internalListRequest<T: Hashable>(keyType: T.Type, onlyFirst: Bool) -> Set<UInt64>? {
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
    
    private func internalCancelRequests(ids: Set<UInt64>) {
        for requestId in ids {
            if let requestData = mutex.synchronized({ self.requestList[requestId] }) {
                requestData.cancel(queueForResponse: queueForResponse)
            }
        }
    }
    
    
    //MARK: Private types
    private struct RequestData {
        let requestId: UInt64
        let endpoint: WebServiceEndpoint
        let cancelHandler: ()->Void
        
        func cancel(queueForResponse: DispatchQueue) {
            cancelHandler()
            
            let queue = endpoint.queueForRequest ?? queueForResponse
            queue.async {
                self.endpoint.canceledRequest(requestId: self.requestId)
            }
        }
    }
    
    private enum RequestState {
        case inWork
        case completed
        case error
        case canceled
    }
    
    private class ReadStorageDependRequestInfo {
        private let mutex = PThreadMutexLock()
        let dependencyType: ReadStorageDependencyType
        
        private var _state: RequestState = .inWork
        private var _isDuplicate: Bool = false
        
        var state: RequestState { return mutex.synchronized { self._state } }
        var isDuplicate: Bool { return mutex.synchronized { self._isDuplicate } }
        
        init(dependencyType: ReadStorageDependencyType) {
            self.dependencyType = dependencyType
        }
        
        func setDuplicate() {
            mutex.synchronized {
                self._isDuplicate = true
                self._state = .canceled
            }
        }
        
        func setState(_ state: RequestState) {
            mutex.synchronized {
                self._isDuplicate = false
                self._state = state
            }
        }
        
        func canRead() -> Bool {
            switch dependencyType {
            case .notDepend: return true
            case .dependSuccessResult: return state != .completed
            case .dependFull: return state != .completed && state != .canceled && !isDuplicate
            }
        }
    }
}

