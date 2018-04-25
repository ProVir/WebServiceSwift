//
//  WebService.swift
//  WebServiceSwift 2.2.0
//
//  Created by ViR (Короткий Виталий) on 14.06.2017.
//  Updated to 2.2.0 by ViR (Короткий Виталий) on 18.04.2018.
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
        - isStorageRequest: Bool flag - response from storage or server
        - response: Response enum with results
     */
    func webServiceResponse(request:WebServiceBaseRequesting, isStorageRequest:Bool, response:WebServiceAnyResponse)
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
    public init(engines:[WebServiceEngining],
                storages:[WebServiceStoraging],
                queueForResponse:DispatchQueue = DispatchQueue.main) {
        
        self.engines = engines
        self.storages = storages
        
        self.queueForResponse = queueForResponse
    }
    
    deinit {
        let (requestList, requestUseEngines) = mutex.synchronized({ (self.requestList, self.requestUseEngines) })
        
        //End networkActivityIndicator for all requests
        WebService.staticMutex.synchronized {
            for (_, listRequests) in requestList {
                WebService.networkActivityIndicatorRequestIds.subtract(listRequests)
            }
        }
        
        
        //Cancel all requests for engine
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for (requestId, engine) in requestUseEngines {
                //Cancel in queue
                if let queue = engine.queueForRequest {
                    queue.async {
                        engine.cancelRequest(requestId: requestId)
                    }
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
    
    private let engines:[WebServiceEngining]
    private let storages:[WebServiceStoraging]
    
    private var requestList: [AnyHashable: Set<UInt64>] = [:]
    private var requestUseEngines: [UInt64: WebServiceEngining] = [:]
    
    
    
    
    // MARK: Settings
    
    /// Default delegate for responses. Apply before call new request.
    public weak var delegate: WebServiceDelegate?
    
    /// Test to equal requests and send error if this request in process and wait data from server. Apply before call new request. Use only if `WebServiceBaseRequesting.excludeDuplicate == nil`. Default: false.
    public var excludeDuplicateRequestsDefault = false
    
    /// Call response closures and delegates in dispath queue. Default: main thread.
    public let queueForResponse:DispatchQueue
    
    
    
    
    // MARK: Control requests
    
    /**
     Returns a Boolean value indicating whether the current queue contains the given request.
     
     - Parameter request: The request to find in the current queue.
     - Returns: `true` if the request was found in the current queue; otherwise, `false`.
     */
    public func containsRequest(request:WebServiceBaseRequesting) -> Bool {
        return containsRequest(requestKey: request.requestKey)
    }
    
    /**
     Returns a Boolean value indicating whether the current queue contains the given request.
     
     - Parameter requestKey: The requestKey to find in the current queue.
     - Returns: `true` if the request with requestKey was found in the current queue; otherwise, `false`.
     */
    public func containsRequest(requestKey:AnyHashable?) -> Bool {
        return (internalListRequest(requestKey:requestKey)?.count ?? 0) > 0
    }
    
    /**
     Returns a Boolean value indicating whether the current queue contains the given requests.
     
     - Parameter requestKeyType: The type requestKey to find in the all current queue.
     - Returns: `true` if one request with requestKey.Type was found in the current queue; otherwise, `false`.
     */
    public func containsRequest<T: Hashable>(requestKeyType: T.Type) -> Bool {
        return (internalListRequest(requestKeyType: requestKeyType, onlyFirst: true)?.count ?? 0) > 0
    }
    
    
    /**
     Cancel all requests with equal this request.
     
     Signal cancel send to engine, but real canceled implementation in engine.
     
     - Parameter request: The request to find in the current queue.
     */
    public func cancelRequest(request:WebServiceBaseRequesting) {
        cancelRequest(requestKey: request.requestKey)
    }
    
    /**
     Cancel all requests with requestKey.
     
     Signal cancel send to engine, but real canceled implementation in engine.
     
     - Parameter requestKey: The requestKey to find in the current queue.
     */
    public func cancelRequest(requestKey:AnyHashable?) {
        if let list = internalListRequest(requestKey: requestKey) {
            internalCancelRequests(ids: list)
        }
    }
    
    
    /**
     Cancel all requests with requestKey.Type.
     
     Signal cancel send to engine, but real canceled implementation in engine.
     
     - Parameter requestKeyType: The requestKey.Type to find in the current queue.
     */
    public func cancelRequest<T: Hashable>(requestKeyType: T.Type) {
        if let list = internalListRequest(requestKeyType: requestKeyType, onlyFirst: false) {
            internalCancelRequests(ids: list)
        }
    }
    
    
    /**
     Cancel all requests in current queue.
 
     Signal cancel send to engine, but real canceled implementation in engine.
     */
    public func cancelAllRequests() {
        var allList = Set<UInt64>()
        
        mutex.synchronized() {
            for (_, list) in requestList {
                allList.formUnion(list)
            }
        }
        
        internalCancelRequests(ids: allList)
    }
    
    /**
     List all requestKey in current queue for Type
     
     - Parameter type: The requestKey.Type to find in the current queue.
     - Returns: list requestKeys for Type
     */
    public func allRequestKeys<T: Hashable>(type: T.Type = T.self) -> [T] {
        mutex.lock()
        defer { mutex.unlock() }
        
        var list = [T]()
        
        for requestKey in requestList.keys {
            if let key = requestKey.base as? T {
                list.append(key)
            }
        }
        
        return list
    }
    
    
    // MARK: Requests with closure
    
    /**
     Request for server (and to storage, if need). Response result in closure.
     
     - Parameters: 
        - request: The request data. 
        - dataFromStorage: Optional. Closure for read data from storage. if read data after data from server - cloure not call. If `closure == nil`, data not read from storage.
        - completionResponse: Optional. Closure for response result from server.
     */
    public func performRequest(_ request:WebServiceBaseRequesting, dataFromStorage:((_ data:Any) -> Void)? = nil, completionResponse:@escaping (_ response:WebServiceAnyResponse) -> Void) {
        let requestKey = request.requestKey
        
        
        //Duplicate requests
        if requestKey != nil && (request.excludeDuplicate ?? excludeDuplicateRequestsDefault) && containsRequest(requestKey: requestKey) {
            completionResponse(.duplicateRequest)
            return
        }
        
        
        //Engine and Storage
        guard let engine = internalFindEngine(request: request) else {
            completionResponse(.error(WebServiceRequestError.noFoundEngine))
            return
        }
        
        let storage = internalFindStorage(request: request)
        
        let requestId = internalNewRequestId()
        internalAddRequest(requestId: requestId, requestKey: requestKey, engine: engine)
        
        
        //Request in work
        var requestStatus = RequestStatus.inWork
        
        
        //Step #3: Call this closure with result response
        let completeHandlerResponse:(WebServiceAnyResponse) -> Void = { [weak self, queueForResponse = self.queueForResponse] response in
            
            //Usually main thread
            queueForResponse.async {
                guard requestStatus == .inWork else {
                    return
                }
                
                self?.internalRemoveRequest(requestId: requestId, requestKey: requestKey)
                
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
        let dataHandler:(Any) -> Void = { (data) in
            do {
                let resultData = try engine.dataHandler(request: request,
                                                        data: data,
                                                        isRawFromStorage: false)
                
                if let resultData = resultData {
                    storage?.writeData(request: request, data: data, isRaw: true)
                    storage?.writeData(request: request, data: resultData, isRaw: false)
                }
                
                completeHandlerResponse(.data(resultData))
            }
            catch {
                completeHandlerResponse(.error(error))
            }
        }
        
        
        //Step #1: Beginer request closure
        let requestHandler = {
            engine.performRequest(requestId: requestId,
                           request: request,
                           completionWithData: { data in
                            
                            //Raw data from server
                            guard requestStatus == .inWork else {
                                return
                            }
                            
                            if let queue = engine.queueForDataHandler {
                                queue.async {
                                    dataHandler(data)
                                }
                            }
                            else {
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
            queue.async {
                requestHandler()
            }
        }
        else {
            requestHandler()
        }
        
        
        
        //Read from storage
        if let dataFromStorage = dataFromStorage,
            let storage = storage,
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
     - dataFromStorage: Optional. Closure for read data from storage. if read data after data from server - cloure not call. If `closure == nil`, data not read from storage.
     - completionResponse: Optional. Closure for response result from server.
     */
    public func performRequest<RequestType: WebServiceRequesting>(_ request:RequestType, dataFromStorage:((_ data:RequestType.ResultType) -> Void)? = nil, completionResponse:@escaping (_ response:WebServiceResponse<RequestType.ResultType>) -> Void) {
        
        //DataFromStorage
        let dataFromStorageInternal:((_ data:Any) -> Void)?
        if let dataFromStorage = dataFromStorage {
            dataFromStorageInternal = { if let data = $0 as? RequestType.ResultType { dataFromStorage(data) } }
        } else {
            dataFromStorageInternal = nil
        }
        

        //Real request
        performRequest(request as WebServiceBaseRequesting, dataFromStorage: dataFromStorageInternal, completionResponse: { completionResponse( $0.convert() ) })
    }
    
    
    /**
     Request for only storage. Response result in closure.
     
     - Parameters:
        - request: The request data.
        - completionResponse: Closure for read data from storage.
        - response: result read from storage.
     */
    public func readStorage(_ request:WebServiceBaseRequesting, completionResponse:@escaping (_ response:WebServiceAnyResponse) -> Void) {
        if let storage = internalFindStorage(request: request) {
            internalReadStorage(storage: storage, request: request, completionResponse: completionResponse)
        }
        else {
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
    public func readStorage<RequestType: WebServiceRequesting>(_ request:RequestType, completionResponse:@escaping (_ response:WebServiceResponse<RequestType.ResultType>) -> Void) {
        if let storage = internalFindStorage(request: request) {
            //CompletionResponse
            let completionResponseInternal:(_ response:WebServiceAnyResponse) -> Void = { completionResponse($0.convert()) }
            
            //Request
            internalReadStorage(storage: storage, request: request, completionResponse: completionResponseInternal)
        }
        else {
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
    public func performRequest(_ request:WebServiceBaseRequesting, includeResponseStorage:Bool = false, customDelegate:WebServiceDelegate? = nil) {
        if let delegate = customDelegate ?? self.delegate {
            performRequest(request,
                     dataFromStorage: includeResponseStorage
                        ? { [weak delegate] data in
                            if let delegate = delegate {
                                delegate.webServiceResponse(request:request, isStorageRequest:true, response:.data(data))
                            }
                            } : nil,
                     completionResponse: { [weak delegate] response in
                        if let delegate = delegate {
                            delegate.webServiceResponse(request:request, isStorageRequest:false, response:response)
                        }
            })
        }
        else {
            performRequest(request, dataFromStorage: nil, completionResponse: { _ in })
        }
    }
    
    
    /**
     Request for only storage. Response result in default or custom delegate.
     
     - Parameters:
        - request: The request data.
        - customDelegate: Optional. Unique delegate for current request.
     */
    public func readStorage(_ request:WebServiceBaseRequesting, customDelegate:WebServiceDelegate? = nil) {
        if let delegate = customDelegate ?? self.delegate {
            readStorage(request,
                                    completionResponse: { [weak delegate] response in
                                        if let delegate = delegate {
                                            delegate.webServiceResponse(request:request, isStorageRequest:true, response:response)
                                        }
            })
        }
    }
    
    
    
    // MARK: - Private functions
    private func internalReadStorage(storage:WebServiceStoraging, request:WebServiceBaseRequesting, completionResponse:@escaping (_ response:WebServiceAnyResponse) -> Void) {
        do {
            try storage.readData(request: request) { [weak self, queueForResponse = self.queueForResponse] isRawData, response in
                if isRawData, let rawData = response.dataResponse() {
                    if let engine = self?.internalFindEngine(request: request, rawDataForRestoreFromStorage: rawData) {
                        
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
                            queue.async {
                                handler()
                            }
                        }
                        else {
                            handler()
                        }
                    }
                    else {
                        queueForResponse.async {
                            completionResponse(.error(WebServiceRequestError.noFoundEngine))
                        }
                    }
                }
                else {
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
    private func internalFindEngine(request:WebServiceBaseRequesting, rawDataForRestoreFromStorage:Any? = nil) -> WebServiceEngining? {
        for engine in self.engines {
            if engine.isSupportedRequest(request, rawDataForRestoreFromStorage: rawDataForRestoreFromStorage) {
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
    private static var lastRequestId:UInt64 = 0
    private func internalNewRequestId() -> UInt64 {
        WebService.staticMutex.lock()
        defer { WebService.staticMutex.unlock() }
        
        WebService.lastRequestId = WebService.lastRequestId &+ 1
        return WebService.lastRequestId
    }
    
    private func internalAddRequest(requestId:UInt64, requestKey:AnyHashable?, engine:WebServiceEngining) {
        if engine.useNetworkActivityIndicator {
            WebService.staticMutex.lock()
            WebService.networkActivityIndicatorRequestIds.insert(requestId)
            WebService.staticMutex.unlock()
        }
        
        //Thread safe
        mutex.lock()
        defer { mutex.unlock() }
        
        let key = requestKey ?? AnyHashable(EmptyKey())
        
        var list = requestList[key] ?? Set<UInt64>()
        list.insert(requestId)
        requestList[key] = list
        
        requestUseEngines[requestId] = engine
    }
    
    private func internalRemoveRequest(requestId:UInt64, requestKey:AnyHashable?) {
        WebService.staticMutex.lock()
        WebService.networkActivityIndicatorRequestIds.remove(requestId)
        WebService.staticMutex.unlock()
        
        
        //Thread safe
        mutex.lock()
        defer { mutex.unlock() }
        
        let key = requestKey ?? AnyHashable(EmptyKey())
        
        if var list = requestList[key] {
            list.remove(requestId)
            
            if list.isEmpty {
                requestList.removeValue(forKey: key)
            }
        }
        
        requestUseEngines.removeValue(forKey: requestId)
    }
    
    private func internalListRequest(requestKey:AnyHashable?) -> Set<UInt64>? {
        mutex.lock()
        defer { mutex.unlock() }
        
        let key = requestKey ?? AnyHashable(EmptyKey())
        return requestList[key]
    }
    
    private func internalListRequest<T: Hashable>(requestKeyType:T.Type, onlyFirst: Bool) -> Set<UInt64>? {
        mutex.lock()
        defer { mutex.unlock() }
        
        var ids = Set<UInt64>()
        
        for (requestKey, requestIds) in requestList {
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
            if let engine = mutex.synchronized({ self.requestUseEngines[requestId] }) {
                
                //Cancel in queue
                if let queue = engine.queueForRequest {
                    queue.async {
                        engine.cancelRequest(requestId: requestId)
                    }
                } else {
                    //Or in current thread
                    engine.cancelRequest(requestId: requestId)
                }
            }
        }
    }
    
    private struct EmptyKey: Hashable {
        var hashValue: Int { return 0 }
        static func ==(lhs: EmptyKey, rhs: EmptyKey) -> Bool {
            return true
        }
    }
    
    private enum RequestStatus {
        case inWork
        case completed
        case error
        case canceled
    }
    
}


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
