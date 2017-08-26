//
//  WebService.swift
//  WebService 2.0.swift
//
//  Created by ViR (Короткий Виталий) on 14.06.17.
//  Copyright © 2017 ProVir. All rights reserved.
//



import Foundation

/**
 WebService general error enum for requests
 
 - `noFoundEngine`: If engine not found in `[engines]` for request
 - `noFoundStorage`: If storage not found in `[storages]` for request
 - `general(code, data)`: Custom error with code and data
 */
public enum WebServiceRequestError: Error {
    case noFoundEngine
    case noFoundStorage
    
    case notSupportRequest
    case notSupportDataHandler
    
    /// Code + data
    case general(Int, Any?)
}


/**
 WebService result response from engine
 
 - `data(Any?)`: Success response with data
 - `error(Error)`: Error response
 - `canceledRequest`: Reqest canceled (called `WebService.cancelRequest()` method for this request or group requests)
 - `duplicateRequest`: If `excludeDuplicateRequests == true` and this request contained in queue
 */
public enum WebServiceResponse {
    case data(Any?)
    case error(Error)
    case canceledRequest
    case duplicateRequest
    
    
    /// Data if success response
    func dataResponse() -> Any? {
        switch self {
        case .data(let d): return d
        default: return nil
        }
    }
    
    /// Error if response completed with error
    func errorResponse() -> Error? {
        switch self {
        case .error(let err): return err
        default: return nil
        }
    }
    
    /// Is canceled request
    var isCanceled:Bool {
        switch self {
        case .canceledRequest: return true
        default: return false
        }
    }
    
    /// Error duplicate for request
    var isDuplicateError:Bool {
        switch self {
        case .duplicateRequest: return true
        default: return false
        }
    }
}

/// WebService Delegate for responses
public protocol WebServiceDelegate: class {
    
    /**
     Response from storage or server
     
     - Parameters:
        - request: Original request
        - isStorageRequest: Bool flag - response from storage or server
        - response: Response enum with results
     */
    func webServiceResponse(request:WebServiceRequesting, isStorageRequest:Bool, response:WebServiceResponse)
}


/// Controller for work. All requests are performed through it.
public class WebService {
    
    /**
     Constructor for WebService.
     
     - Parameters:
        - engines: All sorted engines that support all requests.
        - storages: All sorted storages that support all requests.
    */
    public init(engines:[WebServiceEngining], storages:[WebServiceStoraging]) {
        self.engines = engines
        self.storages = storages
    }
    
    private let engines:[WebServiceEngining]
    private let storages:[WebServiceStoraging]
    
    private var requestList = Dictionary<AnyHashable, Set<UInt64>>()
    private var requestUseEngines = Dictionary<UInt64, WebServiceEngining>()
    
    
    
    // MARK: Settings
    
    /// Default delegate for responses. Apply before call new request.
    public weak var delegate: WebServiceDelegate?
    
    /// Test to equal requests and send error if this request in process and wait data from server. Apply before call new request. Default: false.
    public var excludeDuplicateRequests = false
    
    
    
    // MARK: Control requests
    
    /**
     Returns a Boolean value indicating whether the current queue contains the given request.
     
     - Parameter request: The request to find in the current queue.
     - Returns: `true` if the request was found in the current queue; otherwise, `false`.
     */
    public func containsRequest(request:WebServiceRequesting) -> Bool {
        return containsRequest(requestKey: request.requestKey)
    }
    
    /**
     Returns a Boolean value indicating whether the current queue contains the given request.
     
     - Parameter requestKey: The requestKey to find in the current queue.
     - Returns: `true` if the request with requestKey was found in the current queue; otherwise, `false`.
     */
    public func containsRequest(requestKey:AnyHashable?) -> Bool {
        return (listRequest(requestKey:requestKey)?.count ?? 0) > 0
    }
    
    /**
     Cancel all requests with equal this request.
     
     Signal cancel send to engine, but real canceled implementation in engine.
     
     - Parameter request: The request to find in the current queue.
     */
    public func cancelRequest(request:WebServiceRequesting) {
        cancelRequest(requestKey: request.requestKey)
    }
    
    /**
     Cancel all requests with requestKey.
     
     Signal cancel send to engine, but real canceled implementation in engine.
     
     - Parameter requestKey: The requestKey to find in the current queue.
     */
    public func cancelRequest(requestKey:AnyHashable?) {
        if let list = listRequest(requestKey: requestKey) {
            for requestId in list {
                if let engine = requestUseEngines[requestId] {
                    engine.cancelRequest(requestId: requestId)
                }
            }
        }
    }
    
    /// Cancel all requests in current queue.
    ///
    /// Signal cancel send to engine, but real canceled implementation in engine.
    public func cancelAllRequests() {
        var allList = Set<UInt64>()
        
        for (_, list) in requestList {
            allList.formUnion(list)
        }
        
        for requestId in allList {
            if let engine = requestUseEngines[requestId] {
                engine.cancelRequest(requestId: requestId)
            }
        }
    }
    
    
    // MARK: Requests with closure
    
    /**
     Request for server (and to storage, if need). Response result in closure.
     
     - Parameters: 
        - request: The request data. 
        - dataFromStorage: Optional. Closure for read data from storage. if read data after data from server - cloure not call. If `closure == nil`, data not read from storage.
        - completionResponse: Optional. Closure for response result from server.
     */
    public func request(_ request:WebServiceRequesting, dataFromStorage:((_ data:Any) -> Void)? = nil, completionResponse:((_ response:WebServiceResponse) -> Void)?) {
        let requestKey = request.requestKey
        
        
        //Duplicate requests
        if requestKey != nil && excludeDuplicateRequests && containsRequest(requestKey: requestKey) {
            completionResponse?(.duplicateRequest)
            return
        }
        
        
        //Engine and Storage
        guard let engine = engineForRequest(request) else {
            completionResponse?(.error(WebServiceRequestError.noFoundEngine))
            return
        }
        
        let storage = storageForRequest(request)
        
        let requestId = newRequestId()
        addRequest(requestId: requestId, requestKey: requestKey, engine: engine)
        
        //Request in work
        var requestStatus = RequestStatus.inWork
        
        do {
            try engine.request(requestId: requestId,
                               request: request,
                               saveRawDataToStorage: { rawData in
                                storage?.writeData(request: request, data: rawData, isRaw: true)
                                
            },
                               completionResponse: { response in
                                
                                if requestStatus != .inWork {
                                    return
                                }
                                
                                
                                self.removeRequest(requestId: requestId, requestKey: requestKey)
                                
                                
                                switch response {
                                case .canceledRequest: requestStatus = .canceled
                                case .duplicateRequest, .error: requestStatus = .error
                                case .data(let data): requestStatus = .completed
                                if let storage = storage, let data = data {
                                    storage.writeData(request: request, data: data, isRaw: false)
                                    }
                                }
                                
                                completionResponse?(response)
            })
        } catch {
            removeRequest(requestId: requestId, requestKey: requestKey)
            completionResponse?(.error(error))
        }
        
        
        //Read from storage
        if let dataFromStorage = dataFromStorage,
            let storage = storage,
            (requestStatus == .inWork || requestStatus == .error) {
            
            self.requestReadStorage(storage: storage, request: request) { response in
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
     Request for only storage. Response result in closure.
     
     - Parameters:
        - request: The request data.
        - completionResponse: Closure for read data from storage.
        - response: result read from storage.
     */
    public func requestReadStorage(_ request:WebServiceRequesting, completionResponse:@escaping (_ response:WebServiceResponse) -> Void) {
        if let storage = storageForRequest(request) {
            requestReadStorage(storage: storage, request: request, completionResponse: completionResponse)
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
    public func request(_ request:WebServiceRequesting, includeResponseStorage:Bool = false, customDelegate:WebServiceDelegate? = nil) {
        if let weakDelegate = customDelegate ?? self.delegate {
            self.request(request,
                         dataFromStorage: includeResponseStorage
                            ? { [weak weakDelegate] data in
                                if let delegate = weakDelegate {
                                    delegate.webServiceResponse(request:request, isStorageRequest:true, response:.data(data))
                                }
                                } : nil,
                         completionResponse: { [weak weakDelegate] response in
                            if let delegate = weakDelegate {
                                delegate.webServiceResponse(request:request, isStorageRequest:false, response:response)
                            }
            })
        }
        else {
            self.request(request, dataFromStorage: nil, completionResponse: nil)
        }
    }
    
    
    /**
     Request for only storage. Response result in default or custom delegate.
     
     - Parameters:
        - request: The request data.
        - customDelegate: Optional. Unique delegate for current request.
     */
    public func requestReadStorage(_ request:WebServiceRequesting, customDelegate:WebServiceDelegate? = nil) {
        if let weakDelegate = customDelegate ?? self.delegate {
            self.requestReadStorage(request,
                                    completionResponse: { [weak weakDelegate] response in
                                        if let delegate = weakDelegate {
                                            delegate.webServiceResponse(request:request, isStorageRequest:true, response:response)
                                        }
            })
        }
    }
    
    
    
    // MARK: - Private functions
    private func requestReadStorage(storage:WebServiceStoraging, request:WebServiceRequesting, completionResponse:@escaping (_ response:WebServiceResponse) -> Void) {
        do {
            try storage.readData(request: request) { isRawData, response in
                if isRawData, let rawData = response.dataResponse() {
                    if let engine = self.engineForRequest(request, rawDataForRestoreFromStorage: rawData) {
                        do {
                            try engine.processRawDataFromStorage(rawData: rawData, request: request, completeResponse: completionResponse)
                            
                        } catch {
                            completionResponse(.error(error))
                        }
                    }
                    else {
                        completionResponse(.error(WebServiceRequestError.noFoundEngine))
                    }
                }
                else {
                    completionResponse(response)
                }
            }
        } catch {
            completionResponse(.error(error))
        }
    }
    
    
    // MARK: Find engines and storages
    private func engineForRequest(_ request:WebServiceRequesting, rawDataForRestoreFromStorage:Any? = nil) -> WebServiceEngining? {
        for engine in self.engines {
            if engine.isSupportedRequest(request, rawDataForRestoreFromStorage: rawDataForRestoreFromStorage) {
                return engine
            }
        }
        
        return nil
    }
    
    private func storageForRequest(_ request:WebServiceRequesting) -> WebServiceStoraging? {
        for storage in self.storages {
            if storage.isSupportedRequestForStorage(request) {
                return storage
            }
        }
        
        return nil
    }
    
    
    // MARK: Request Ids
    private static var lastRequestId:UInt64 = 0
    private func newRequestId() -> UInt64 {
        WebService.lastRequestId = WebService.lastRequestId &+ 1
        return WebService.lastRequestId
    }
    
    private func addRequest(requestId:UInt64, requestKey:AnyHashable?, engine:WebServiceEngining) {
        let key = requestKey ?? AnyHashable(EmptyKey())
        
        var list = requestList[key] ?? Set<UInt64>()
        list.insert(requestId)
        requestList[key] = list
        
        requestUseEngines[requestId] = engine
    }
    
    private func removeRequest(requestId:UInt64, requestKey:AnyHashable?) {
        let key = requestKey ?? AnyHashable(EmptyKey())
        
        if var list = requestList[key] {
            list.remove(requestId)
            
            if list.isEmpty {
                requestList.removeValue(forKey: key)
            }
        }
        
        requestUseEngines.removeValue(forKey: requestId)
    }
    
    private func listRequest(requestKey:AnyHashable?) -> Set<UInt64>? {
        let key = requestKey ?? AnyHashable(EmptyKey())
        return requestList[key]
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
