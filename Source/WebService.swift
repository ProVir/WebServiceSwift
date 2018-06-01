//
//  WebService.swift
//  WebServiceSwift 2.3.0
//
//  Created by ViR (Короткий Виталий) on 14.06.2017.
//  Updated to 2.3.0 by ViR (Короткий Виталий) on 25.05.2018.
//  Copyright © 2017 ProVir. All rights reserved.
//

import Foundation

#if os(iOS)
import UIKit
#endif

/// WebService Delegate for responses
public protocol WebServiceDelegate: class {
    
    /**
     Response from storage or server
     
     - Parameters:
        - request: Original request
        - key: key from `performRequest` method if have
        - isStorageRequest: Bool flag - response from storage or server
        - response: Response enum with results
     */
    func webServiceResponse(request: WebServiceBaseRequesting, key: AnyHashable?, isStorageRequest: Bool, response: WebServiceAnyResponse)
}


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
    
    /**
     Constructor for WebService.
     
     - Parameters:
        - engines: All sorted engines that support all requests.
        - storages: All sorted storages that support all requests.
        - queueForResponse: Dispatch Queue for results response. Thread for public method call and queueForResponse recommended be equal. Default: main thread.
     */
    public init(engines: [WebServiceEngining],
                storages: [WebServiceStoraging],
                queueForResponse: DispatchQueue = DispatchQueue.main) {
        
        self.engines = engines
        self.storages = storages
        
        self.queueForResponse = queueForResponse
    }
    
    deinit {
        let (requestList, requestUseEngines) = mutex.synchronized({ (self.requestList, self.requestUseEngines) })
        
        //End networkActivityIndicator for all requests
        WebService.staticMutex.synchronized {
            WebService.networkActivityIndicatorRequestIds.subtract(requestList)
        }
        
        //Cancel all requests for engine
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for (requestId, engine) in requestUseEngines {
                //Cancel in queue
                if let queue = engine.queueForRequest {
                    queue.async { engine.cancelRequest(requestId: requestId) }
                } else {
                    //Or in main thread
                    engine.cancelRequest(requestId: requestId)
                }
            }
        }
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
    
    private let engines: [WebServiceEngining]
    private let storages: [WebServiceStoraging]
    
    private var requestList: Set<UInt64> = []   //All requests
    private var requestUseEngines: [UInt64: WebServiceEngining] = [:]
    
    private var requestsForTypes: [String: Set<UInt64>] = [:]        //[Request.Type: [Id]]
    private var requestsForHashs: [AnyHashable: Set<UInt64>] = [:]   //[Request<Hashable>: [Id]]
    private var requestsForKeys:  [AnyHashable: Set<UInt64>] = [:]   //[Key: [Id]]
    
    private weak var readStorageDependNextRequestWait: ReadStorageDependRequestInfo?
    
    
    // MARK: Settings
    
    /// Default delegate for responses. Apply before call new request.
    public weak var delegate: WebServiceDelegate?
    
    /// Perform response closures and delegates in dispath queue. Default: main thread.
    public let queueForResponse: DispatchQueue
    
    
    // MARK: Control requests
    
    /**
     Returns a Boolean value indicating whether the current queue contains the given request.
     
     - Parameter request: The request to find in the current queue.
     - Returns: `true` if the request was found in the current queue; otherwise, `false`.
     */
    public func containsRequest<T: WebServiceBaseRequesting & Hashable>(request: T) -> Bool {
        return mutex.synchronized { !(requestsForHashs[request]?.isEmpty ?? true) }
    }
    
    /**
     Returns a Boolean value indicating whether the current queue contains the given requests.
     
     - Parameter requestType: The type request to find in the all current queue.
     - Returns: `true` if one request with WebServiceBaseRequesting.Type was found in the current queue; otherwise, `false`.
     */
    public func containsRequest(requestType: WebServiceBaseRequesting.Type) -> Bool {
        return mutex.synchronized { !(requestsForTypes["\(requestType)"]?.isEmpty ?? true) }
    }
    
    /**
     Returns a Boolean value indicating whether the current queue contains the given request.
     
     - Parameter requestKey: The requestKey to find in the current queue.
     - Returns: `true` if the request with requestKey was found in the current queue; otherwise, `false`.
     */
    public func containsRequest(key: AnyHashable) -> Bool {
        return mutex.synchronized { !(requestsForKeys[key]?.isEmpty ?? true) }
    }
    
    /**
     Returns a Boolean value indicating whether the current queue contains the given requests.
     
     - Parameter requestKeyType: The type requestKey to find in the all current queue.
     - Returns: `true` if one request with requestKey.Type was found in the current queue; otherwise, `false`.
     */
    public func containsRequest<T: Hashable>(keyType: T.Type) -> Bool {
        return (internalListRequest(keyType: keyType, onlyFirst: true)?.count ?? 0) > 0
    }
    
    
    /**
     Cancel all requests with equal this request.
     
     Signal cancel send to engine, but real canceled implementation in engine.
     
     - Parameter request: The request to find in the current queue.
     */
    public func cancelRequests<T: WebServiceBaseRequesting & Hashable>(request: T) {
        if let list = mutex.synchronized({ requestsForHashs[request] }) {
            internalCancelRequests(ids: list)
        }
    }
    
    /**
     Cancel all requests for request type.
     
     Signal cancel send to engine, but real canceled implementation in engine.
     
     - Parameter requestType: The WebServiceBaseRequesting.Type to find in the current queue.
     */
    public func cancelRequests(requestType: WebServiceBaseRequesting.Type) {
        if let list = mutex.synchronized({ requestsForTypes["\(requestType)"] }) {
            internalCancelRequests(ids: list)
        }
    }
    
    /**
     Cancel all requests with requestKey.
     
     Signal cancel send to engine, but real canceled implementation in engine.
     
     - Parameter requestKey: The requestKey to find in the current queue.
     */
    public func cancelRequests(key: AnyHashable) {
        if let list = mutex.synchronized({ requestsForKeys[key] }) {
            internalCancelRequests(ids: list)
        }
    }
    
    /**
     Cancel all requests with requestKey.Type.
     
     Signal cancel send to engine, but real canceled implementation in engine.
     
     - Parameter requestKeyType: The requestKey.Type to find in the current queue.
     */
    public func cancelRequests<T: Hashable>(keyType: T.Type) {
        if let list = internalListRequest(keyType: keyType, onlyFirst: false) {
            internalCancelRequests(ids: list)
        }
    }
    
    /**
     Cancel all requests in current queue.
     
     Signal cancel send to engine, but real canceled implementation in engine.
     */
    public func cancelAllRequests() {
        let requestList = mutex.synchronized { self.requestList }
        internalCancelRequests(ids: requestList)
    }
    
    
    // MARK: Requests with closure
    
    /**
     Request for server (and to storage, if need). Response result in closure.
     
     - Parameters:
        - request: The request data.
        - key: unique key for controling requests: caontaint and canceled. Also use for excludeDuplicate. Default: nil.
        - excludeDuplicate: Exclude duplicate requests. Equal requests alogorithm: test for key if not null, else test requests equal if request is hashable.
        - dataFromStorage: Optional. Closure for read data from storage. if read data after data from server - cloure not call. If `closure == nil`, data not read from storage.
        - completionResponse: Optional. Closure for response result from server.
     */
    public func performBaseRequest(_ request: WebServiceBaseRequesting, key: AnyHashable? = nil, excludeDuplicate: Bool = false, completionResponse: @escaping (_ response: WebServiceAnyResponse) -> Void) {
        weak var readStorageRequestInfo: ReadStorageDependRequestInfo? = readStorageDependNextRequestWait
        readStorageDependNextRequestWait = nil
        
        let requestHashable = request as? AnyHashable
        
        //Duplicate requests
        if excludeDuplicate, let key = key {
            if containsRequest(key: key) {
                readStorageRequestInfo?.setDuplicate()
                completionResponse(.duplicateRequest)
                return
            }
        } else if excludeDuplicate, let requestHashable = requestHashable {
            if mutex.synchronized({ !(requestsForHashs[requestHashable]?.isEmpty ?? true) }) {
                readStorageRequestInfo?.setDuplicate()
                completionResponse(.duplicateRequest)
                return
            }
        }
        
        //Engine and Storage
        guard let engine = internalFindEngine(request: request) else {
            readStorageRequestInfo?.setState(.error)
            completionResponse(.error(WebServiceRequestError.notFoundEngine))
            return
        }
        
        let storage = internalFindStorage(request: request)
        
        let requestType = type(of: request)
        let requestId = internalNewRequestId()
        internalAddRequest(requestId: requestId, key: key, requestHashable: requestHashable, requestType: requestType, engine: engine)
        
 
        //Request in work
        var requestState = RequestState.inWork
        
        //Step #3: Call this closure with result response
        let completeHandlerResponse: (WebServiceAnyResponse) -> Void = { [weak self, queueForResponse = self.queueForResponse] response in
            //Usually main thread
            queueForResponse.async {
                guard requestState == .inWork else { return }
                
                self?.internalRemoveRequest(requestId: requestId, key: key, requestHashable: requestHashable, requestType: requestType)
                
                switch response {
                case .data(let data):
                    requestState = .completed
                    readStorageRequestInfo?.setState(requestState)
                    completionResponse(.data(data))
                    
                case .error(let error):
                    requestState = .error
                    readStorageRequestInfo?.setState(requestState)
                    completionResponse(.error(error))
                    
                case .canceledRequest, .duplicateRequest:
                    requestState = .canceled
                    readStorageRequestInfo?.setState(requestState)
                    completionResponse(.canceledRequest)
                }
            }
        }
        
        //Step #2: Data handler closure for raw data from server
        let dataHandler: (Any) -> Void = { (data) in
            do {
                let resultData = try engine.dataHandler(request: request,
                                                        data: data,
                                                        isRawFromStorage: false)
                
                if let resultData = resultData {
                    storage?.writeData(request: request, data: data, isRaw: true)
                    storage?.writeData(request: request, data: resultData, isRaw: false)
                }
                
                completeHandlerResponse(.data(resultData))
                
            } catch {
                completeHandlerResponse(.error(error))
            }
        }
        
        //Step #1: Beginer request closure
        let requestHandler = {
            engine.performRequest(requestId: requestId,
                                  request: request,
                                  completionWithData: { data in
                                    
                                    //Raw data from server
                                    guard requestState == .inWork else { return }
                                    
                                    if let queue = engine.queueForDataHandler {
                                        queue.async { dataHandler(data) }
                                    } else {
                                        dataHandler(data)
                                    }
                                    
            },
                                  completionWithError: { error in
                                    //Error request
                                    completeHandlerResponse(.error(error))
            },
                                  canceled: {
                                    //Canceled request
                                    completeHandlerResponse(.canceledRequest)
            })
        }
        
        //Step #0: Call request in queue
        if let queue = engine.queueForRequest {
            queue.async { requestHandler() }
        } else {
            requestHandler()
        }
    }
    
    /**
     Request for server (and to storage, if need). Response result in closure.
     
     - Parameters:
        - request: The request data.
        - key: unique key for controling requests: caontaint and canceled. Also use for excludeDuplicate. Default: nil.
        - excludeDuplicate: Exclude duplicate requests. Equal requests alogorithm: test for key if not null, else test requests equal if request is hashable.
        - dataFromStorage: Optional. Closure for read data from storage. if read data after data from server - cloure not call. If `closure == nil`, data not read from storage.
        - completionResponse: Optional. Closure for response result from server.
     */
    public func performRequest<RequestType: WebServiceRequesting>(_ request: RequestType, completionResponse: @escaping (_ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        performBaseRequest(request, key: nil, excludeDuplicate: false, completionResponse: { completionResponse( $0.convert() ) })
    }
    
    
    public func performRequest<RequestType: WebServiceRequesting>(_ request: RequestType, key: AnyHashable, excludeDuplicate: Bool, completionResponse: @escaping (_ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        performBaseRequest(request, key: key, excludeDuplicate: excludeDuplicate, completionResponse: { completionResponse( $0.convert() ) })
    }
    
    public func performRequest<RequestType: WebServiceRequesting & Hashable>(_ request: RequestType, excludeDuplicate: Bool, completionResponse: @escaping (_ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        performBaseRequest(request, key: nil, excludeDuplicate: excludeDuplicate, completionResponse: { completionResponse( $0.convert() ) })
    }
    
    
    
    /**
     Request for only storage. Response result in closure.
     
     - Parameters:
     - request: The request data.
     - completionResponse: Closure for read data from storage.
     - response: result read from storage.
     */
    public func readStorageAnyData(_ request: WebServiceBaseRequesting, dependencyNextRequest: ReadStorageDependencyType = .notDepend, completionResponse: @escaping (_ timeStamp: Date?, _ response: WebServiceAnyResponse) -> Void) {
        if let storage = internalFindStorage(request: request) {
            internalReadStorage(storage: storage, request: request, dependencyNextRequest: dependencyNextRequest, completionResponse: completionResponse)
        } else {
            completionResponse(nil, .error(WebServiceRequestError.notFoundStorage))
        }
    }
    
    /**
     Request for only storage. Response result in closure.
     
     - Parameters:
     - request: The request data.
     - completionResponse: Closure for read data from storage.
     - response: result read from storage.
     */
    public func readStorage<RequestType: WebServiceRequesting>(_ request: RequestType, dependencyNextRequest: ReadStorageDependencyType = .notDepend, completionResponse: @escaping (_ timeStamp: Date?, _ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        if let storage = internalFindStorage(request: request) {
            //CompletionResponse
            let completionResponseInternal:(_ timeStamp: Date?, _ response: WebServiceAnyResponse) -> Void = { completionResponse($0, $1.convert()) }
            
            //Request
            internalReadStorage(storage: storage, request: request, dependencyNextRequest: dependencyNextRequest, completionResponse: completionResponseInternal)
            
        } else {
            completionResponse(nil, .error(WebServiceRequestError.notFoundStorage))
        }
    }
    
    
    // MARK: Requests with delegates
    
    /**
     Request for server (and to storage, if need). Response result in default or custom delegate.
     
     - Parameters:
     - request: The request data.
     - includeResponseStorage: `true` if need read data from storage. if read data after data from server - delegate not call. Default: false.
     - customDelegate: Optional. Unique delegate for current request.
     */
    public func performRequest(_ request: WebServiceBaseRequesting, customDelegate: WebServiceDelegate? = nil) {
        internalPerformRequest(request, key: nil, excludeDuplicate: false, customDelegate: customDelegate)
    }
    
    public func performRequest(_ request: WebServiceBaseRequesting, key: AnyHashable, excludeDuplicate: Bool, customDelegate: WebServiceDelegate? = nil) {
        internalPerformRequest(request, key: key, excludeDuplicate: excludeDuplicate, customDelegate: customDelegate)
    }
    
    public func performRequest<RequestType: WebServiceBaseRequesting & Hashable>(_ request: RequestType, excludeDuplicate: Bool, customDelegate: WebServiceDelegate? = nil) {
        internalPerformRequest(request, key: nil, excludeDuplicate: excludeDuplicate, customDelegate: customDelegate)
    }
    
    
    /**
     Request for only storage. Response result in default or custom delegate.
     
     - Parameters:
     - request: The request data.
     - customDelegate: Optional. Unique delegate for current request.
     */
    public func readStorage(_ request: WebServiceBaseRequesting, key: AnyHashable? = nil, dependencyNextRequest: ReadStorageDependencyType = .notDepend, customDelegate: WebServiceDelegate? = nil) {
        if let delegate = customDelegate ?? self.delegate {
            readStorageAnyData(request, dependencyNextRequest: dependencyNextRequest, completionResponse: { [weak delegate] _, response in
                if let delegate = delegate {
                    delegate.webServiceResponse(request: request, key: key, isStorageRequest: true, response: response)
                }
            })
        }
    }
    
    // MARK: - Private functions
    private func internalPerformRequest(_ request: WebServiceBaseRequesting, key: AnyHashable?, excludeDuplicate: Bool, customDelegate: WebServiceDelegate? = nil) {
        if let delegate = customDelegate ?? self.delegate {
            performBaseRequest(request,
                               key: key,
                               excludeDuplicate: excludeDuplicate,
                               completionResponse: { [weak delegate] response in
                                if let delegate = delegate {
                                    delegate.webServiceResponse(request: request, key: key, isStorageRequest: false, response: response)
                                }
            })
        }
        else {
            performBaseRequest(request, key: key, excludeDuplicate: excludeDuplicate, completionResponse: { _ in })
        }
    }
    
    private func internalReadStorage(storage: WebServiceStoraging, request: WebServiceBaseRequesting, dependencyNextRequest: ReadStorageDependencyType, completionResponse: @escaping (_ timeStamp: Date?, _ response: WebServiceAnyResponse) -> Void) {
        let nextRequestInfo: ReadStorageDependRequestInfo?
        let completionHandler: (_ timeStamp: Date?, _ response: WebServiceAnyResponse) -> Void
        
        //Dependency setup
        if dependencyNextRequest == .notDepend {
            nextRequestInfo = nil
            completionHandler = completionResponse
            
        } else {
            nextRequestInfo = ReadStorageDependRequestInfo(dependencyType: dependencyNextRequest)
            readStorageDependNextRequestWait = nextRequestInfo
            
            completionHandler = { [weak self] timeStamp, response in
                if self?.readStorageDependNextRequestWait === nextRequestInfo {
                    self?.readStorageDependNextRequestWait = nil
                }
                
                if nextRequestInfo?.canRead() ?? true {
                    completionResponse(timeStamp, response)
                } else if nextRequestInfo?.isDuplicate ?? false {
                    completionResponse(timeStamp, .duplicateRequest)
                } else {
                    completionResponse(timeStamp, .canceledRequest)
                }
            }
        }
        
        //Perform read
        do {
            try storage.readData(request: request) { [weak self, queueForResponse = self.queueForResponse] isRawData, timeStamp, response in
                if (nextRequestInfo?.canRead() ?? true) == false {
                    self?.queueForResponse.async {
                        completionHandler(nil, .canceledRequest)
                    }
                    
                } else if isRawData, let rawData = response.dataResponse() {
                    if let engine = self?.internalFindEngine(request: request, rawDataTypeForRestoreFromStorage: type(of: rawData)) {
                        //Handler closure with fined engine for use next
                        let handler = {
                            do {
                                let data = try engine.dataHandler(request: request, data: rawData, isRawFromStorage: true)
                                
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
                        if let queue = engine.queueForDataHandlerFromStorage {
                            queue.async { handler() }
                        } else {
                            handler()
                        }
                        
                    } else {
                        //Not found engine
                        queueForResponse.async {
                            completionHandler(nil, .error(WebServiceRequestError.notFoundEngine))
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
    
    // MARK: Find engines and storages
    private func internalFindEngine(request: WebServiceBaseRequesting, rawDataTypeForRestoreFromStorage: Any.Type? = nil) -> WebServiceEngining? {
        for engine in self.engines {
            if engine.isSupportedRequest(request, rawDataTypeForRestoreFromStorage: rawDataTypeForRestoreFromStorage) {
                return engine
            }
        }
        
        return nil
    }
    
    private func internalFindStorage(request:WebServiceBaseRequesting) -> WebServiceStoraging? {
        for storage in self.storages {
            if storage.isSupportedRequestForStorage(request) {
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
    
    private func internalAddRequest(requestId: UInt64, key: AnyHashable?, requestHashable: AnyHashable?, requestType: WebServiceBaseRequesting.Type, engine: WebServiceEngining) {
        //Increment counts for visible NetworkActivityIndicator in StatusBar if need only for iOS
        #if os(iOS)
        if engine.useNetworkActivityIndicator {
            WebService.staticMutex.lock()
            WebService.networkActivityIndicatorRequestIds.insert(requestId)
            WebService.staticMutex.unlock()
        }
        #endif
        
        //Thread safe
        mutex.lock()
        defer { mutex.unlock() }
        
        requestList.insert(requestId)
        requestsForTypes["\(requestType)", default: Set<UInt64>()].insert(requestId)
        
        if let key = key {
            requestsForKeys[key, default: Set<UInt64>()].insert(requestId)
        }
        
        if let requestHashable = requestHashable {
            requestsForHashs[requestHashable, default: Set<UInt64>()].insert(requestId)
        }

        requestUseEngines[requestId] = engine
    }
    
    private func internalRemoveRequest(requestId: UInt64, key: AnyHashable?, requestHashable: AnyHashable?, requestType: WebServiceBaseRequesting.Type) {
        WebService.staticMutex.lock()
        WebService.networkActivityIndicatorRequestIds.remove(requestId)
        WebService.staticMutex.unlock()
        
        //Thread safe
        mutex.lock()
        defer { mutex.unlock() }

        requestList.remove(requestId)
        
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
  
        requestUseEngines.removeValue(forKey: requestId)
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
    
    private func internalListRequest(requestType: WebServiceBaseRequesting.Type) -> Set<UInt64>? {
        mutex.lock()
        defer { mutex.unlock() }
        
//        let key = "\(requestType)"
//        return requestTypes[key]
        return nil
    }
    
    private func internalCancelRequests(ids: Set<UInt64>) {
        for requestId in ids {
            if let engine = mutex.synchronized({ self.requestUseEngines[requestId] }) {
                //Cancel in queue
                if let queue = engine.queueForRequest {
                    queue.async { engine.cancelRequest(requestId: requestId) }
                } else {
                    //Or in current thread
                    engine.cancelRequest(requestId: requestId)
                }
            }
        }
    }
    
    
    //MARK: Private types
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

