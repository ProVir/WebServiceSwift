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
    public func performBaseRequest(_ request: WebServiceBaseRequesting, key: AnyHashable? = nil, excludeDuplicate: Bool = false, dataFromStorage: ((_ data:Any) -> Void)? = nil, completionResponse: @escaping (_ response: WebServiceAnyResponse) -> Void) {
        let requestHashable = request as? AnyHashable
        
        //Duplicate requests
        if excludeDuplicate, let key = key {
            if containsRequest(key: key) {
                completionResponse(.duplicateRequest)
                return
            }
        } else if excludeDuplicate, let requestHashable = requestHashable {
            if mutex.synchronized({ !(requestsForHashs[requestHashable]?.isEmpty ?? true) }) {
                completionResponse(.duplicateRequest)
                return
            }
        }
        
        //Engine and Storage
        guard let engine = internalFindEngine(request: request) else {
            completionResponse(.error(WebServiceRequestError.noFoundEngine))
            return
        }
        
        let storage = internalFindStorage(request: request)
        
        let requestType = type(of: request)
        let requestId = internalNewRequestId()
        internalAddRequest(requestId: requestId, key: key, requestHashable: requestHashable, requestType: requestType, engine: engine)
        
 
        //Request in work
        var requestStatus = RequestStatus.inWork
        
        //Step #3: Call this closure with result response
        let completeHandlerResponse: (WebServiceAnyResponse) -> Void = { [weak self, queueForResponse = self.queueForResponse] response in
            //Usually main thread
            queueForResponse.async {
                guard requestStatus == .inWork else { return }
                
                self?.internalRemoveRequest(requestId: requestId, key: key, requestHashable: requestHashable, requestType: requestType)
                
                switch response {
                case .data(let data):
                    requestStatus = .completed
                    completionResponse(.data(data))
                    
                case .error(let error):
                    requestStatus = .error
                    completionResponse(.error(error))
                    
                case .canceledRequest, .duplicateRequest:
                    requestStatus = .canceled
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
                                    guard requestStatus == .inWork else { return }
                                    
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
        
        //Read from storage
        if let dataFromStorage = dataFromStorage, let storage = storage,
            (requestStatus == .inWork || requestStatus == .error) {
            
            self.internalReadStorage(storage: storage, request: request) { response in
                switch response {
                case .data(let data):
                    if let data = data, (requestStatus == .inWork || requestStatus == .error) {
                        dataFromStorage(data)
                    }
                default: break
                }
            }
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
    public func performRequest<RequestType: WebServiceRequesting>(_ request: RequestType, dataFromStorage: ((_ data: RequestType.ResultType) -> Void)? = nil, completionResponse: @escaping (_ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        internalPerformRequest(request, key: nil, excludeDuplicate: false, dataFromStorage: dataFromStorage, completionResponse: completionResponse)
    }
    
    
    public func performRequest<RequestType: WebServiceRequesting>(_ request: RequestType, key: AnyHashable, excludeDuplicate: Bool, dataFromStorage: ((_ data: RequestType.ResultType) -> Void)? = nil, completionResponse: @escaping (_ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        internalPerformRequest(request, key: key, excludeDuplicate: excludeDuplicate, dataFromStorage: dataFromStorage, completionResponse: completionResponse)
    }
    
    public func performRequest<RequestType: WebServiceRequesting & Hashable>(_ request: RequestType, excludeDuplicate: Bool, dataFromStorage: ((_ data: RequestType.ResultType) -> Void)? = nil, completionResponse: @escaping (_ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        internalPerformRequest(request, key: nil, excludeDuplicate: excludeDuplicate, dataFromStorage: dataFromStorage, completionResponse: completionResponse)
    }
    
    
    
    /**
     Request for only storage. Response result in closure.
     
     - Parameters:
     - request: The request data.
     - completionResponse: Closure for read data from storage.
     - response: result read from storage.
     */
    public func readStorageAnyData(_ request: WebServiceBaseRequesting, completionResponse: @escaping (_ response: WebServiceAnyResponse) -> Void) {
        if let storage = internalFindStorage(request: request) {
            internalReadStorage(storage: storage, request: request, completionResponse: completionResponse)
        } else {
            completionResponse(.error(WebServiceRequestError.noFoundStorage))
        }
    }
    
    /**
     Request for only storage. Response result in closure.
     
     - Parameters:
     - request: The request data.
     - completionResponse: Closure for read data from storage.
     - response: result read from storage.
     */
    public func readStorage<RequestType: WebServiceRequesting>(_ request: RequestType, completionResponse: @escaping (_ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        if let storage = internalFindStorage(request: request) {
            //CompletionResponse
            let completionResponseInternal:(_ response: WebServiceAnyResponse) -> Void = { completionResponse($0.convert()) }
            
            //Request
            internalReadStorage(storage: storage, request: request, completionResponse: completionResponseInternal)
            
        } else {
            completionResponse(.error(WebServiceRequestError.noFoundStorage))
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
    public func performRequest(_ request: WebServiceBaseRequesting, includeResponseStorage: Bool = false, customDelegate: WebServiceDelegate? = nil) {
        internalPerformRequest(request, key: nil, excludeDuplicate: false, includeResponseStorage: includeResponseStorage, customDelegate: customDelegate)
    }
    
    public func performRequest(_ request: WebServiceBaseRequesting, key: AnyHashable, excludeDuplicate: Bool, includeResponseStorage: Bool = false, customDelegate: WebServiceDelegate? = nil) {
        internalPerformRequest(request, key: key, excludeDuplicate: excludeDuplicate, includeResponseStorage: includeResponseStorage, customDelegate: customDelegate)
    }
    
    public func performRequest<RequestType: WebServiceBaseRequesting & Hashable>(_ request: RequestType, excludeDuplicate: Bool, includeResponseStorage: Bool = false, customDelegate: WebServiceDelegate? = nil) {
        internalPerformRequest(request, key: nil, excludeDuplicate: excludeDuplicate, includeResponseStorage: includeResponseStorage, customDelegate: customDelegate)
    }
    
    
    /**
     Request for only storage. Response result in default or custom delegate.
     
     - Parameters:
     - request: The request data.
     - customDelegate: Optional. Unique delegate for current request.
     */
    public func readStorage(_ request: WebServiceBaseRequesting, key: AnyHashable? = nil, customDelegate: WebServiceDelegate? = nil) {
        if let delegate = customDelegate ?? self.delegate {
            readStorageAnyData(request, completionResponse: { [weak delegate] response in
                if let delegate = delegate {
                    delegate.webServiceResponse(request: request, key: key, isStorageRequest: true, response: response)
                }
            })
        }
    }
    
    // MARK: - Private functions
    private func internalPerformRequest<RequestType: WebServiceRequesting>(_ request: RequestType, key: AnyHashable?, excludeDuplicate: Bool, dataFromStorage: ((_ data: RequestType.ResultType) -> Void)?, completionResponse: @escaping (_ response: WebServiceResponse<RequestType.ResultType>) -> Void) {
        
        //DataFromStorage
        let dataFromStorageInternal: ((_ data: Any) -> Void)?
        if let dataFromStorage = dataFromStorage {
            dataFromStorageInternal = { if let data = $0 as? RequestType.ResultType { dataFromStorage(data) } }
        } else {
            dataFromStorageInternal = nil
        }
        
        //Real request
        performBaseRequest(request, key: key, excludeDuplicate: excludeDuplicate, dataFromStorage: dataFromStorageInternal, completionResponse: { completionResponse( $0.convert() ) })
    }
    
    private func internalPerformRequest(_ request: WebServiceBaseRequesting, key: AnyHashable?, excludeDuplicate: Bool, includeResponseStorage: Bool = false, customDelegate: WebServiceDelegate? = nil) {
        if let delegate = customDelegate ?? self.delegate {
            performBaseRequest(request,
                               key: key,
                               excludeDuplicate: excludeDuplicate,
                               dataFromStorage: includeResponseStorage ? { [weak delegate] data in
                                if let delegate = delegate {
                                    delegate.webServiceResponse(request: request, key: key, isStorageRequest: true, response: .data(data))
                                }
                                } : nil,
                               completionResponse: { [weak delegate] response in
                                if let delegate = delegate {
                                    delegate.webServiceResponse(request: request, key: key, isStorageRequest: false, response: response)
                                }
            })
        }
        else {
            performBaseRequest(request, key: key, excludeDuplicate: excludeDuplicate, dataFromStorage: nil, completionResponse: { _ in })
        }
    }
    
    private func internalReadStorage(storage: WebServiceStoraging, request: WebServiceBaseRequesting, completionResponse: @escaping (_ response: WebServiceAnyResponse) -> Void) {
        do {
            try storage.readData(request: request) { [weak self, queueForResponse = self.queueForResponse] isRawData, response in
                if isRawData, let rawData = response.dataResponse() {
                    if let engine = self?.internalFindEngine(request: request, rawDataTypeForRestoreFromStorage: type(of: rawData)) {
                        //Handler closure with fined engine for use next
                        let handler = {
                            do {
                                let data = try engine.dataHandler(request: request, data: rawData, isRawFromStorage: true)
                                
                                queueForResponse.async {
                                    completionResponse(.data(data))
                                }
                            } catch {
                                queueForResponse.async {
                                    completionResponse(.error(error))
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
                            completionResponse(.error(WebServiceRequestError.noFoundEngine))
                        }
                    }
                    
                } else {
                    //No RAW data
                    self?.queueForResponse.async {
                        completionResponse(response)
                    }
                }
            }
        } catch {
            completionResponse(.error(error))
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
    
    private enum RequestStatus {
        case inWork
        case completed
        case error
        case canceled
    }
}

//MARK: Helpers
private class PThreadMutexLock: NSObject, NSLocking {
    private var mutex = pthread_mutex_t()
    
    override init() {
        super.init()
        
        pthread_mutex_init(&mutex, nil)
    }
    
    deinit {
        pthread_mutex_destroy(&mutex)
    }
    
    func lock() {
        pthread_mutex_lock(&mutex)
    }
    
    func unlock() {
        pthread_mutex_unlock(&mutex)
    }
    
    @discardableResult
    func synchronized<T>(_ handler: () throws -> T) rethrows -> T {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        return try handler()
    }
}
