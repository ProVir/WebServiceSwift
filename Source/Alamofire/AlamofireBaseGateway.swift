//
//  AlamofireBaseGateway.swift
//  WebServiceSwift 4.0.0
//
//  Created by Короткий Виталий (ViR) on 31.05.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation
import Alamofire

/// Base Gateway with support Alamofire.
open class AlamofireBaseGateway: WebServiceGateway {
    public let queueForRequest: DispatchQueue?
    public let queueForDataProcessing: DispatchQueue? = nil
    public let queueForDataProcessingFromStorage: DispatchQueue? = DispatchQueue.global(qos: .utility)
    
    public let useNetworkActivityIndicator: Bool
    
    
    /**
     Constructor for base gateway.
 
     - Parameters:
        - queueForRequest: Thread Dispatch Queue for `perofrmRequest()` and `cancelRequests()` methods.
        - useNetworkActivityIndicator: When `true`, showed networkActivityIndicator in statusBar when requests in process.
    */
    public init(queueForRequest: DispatchQueue?, useNetworkActivityIndicator: Bool) {
        self.queueForRequest = queueForRequest
        self.useNetworkActivityIndicator = useNetworkActivityIndicator
    }
    
    /// Request data with completion closures.
    public struct RequestData {
        public var request: WebServiceBaseRequesting
        
        public var completionWithRawData: (Any) -> Void
        public var completionWithError: (Error) -> Void
        
        /// User optional data, used only in child classes.
        public var innerData: Any?
        
        public init(request: WebServiceBaseRequesting,
                    completionWithRawData: @escaping (Any) -> Void,
                    completionWithError: @escaping (Error) -> Void,
                    innerData: Any? = nil) {
            self.request = request
            self.completionWithRawData = completionWithRawData
            self.completionWithError = completionWithError
            self.innerData = innerData
        }
    }
    
    
    //MARK: - Need Override
    
    /**
     Asks whether the request supports this gateway. Need override.
     
     If `rawDataForRestoreFromStorage != nil`, after this method called `processRawDataFromStorage()` method.
     
     - Parameters:
         - request: Request for test.
         - rawDataTypeForRestoreFromStorage: If no nil - request restore raw data from storage with data.
         - Returns: If request support this gateway - return true.
     */
    open func isSupportedRequest(_ request: WebServiceBaseRequesting, rawDataTypeForRestoreFromStorage: Any.Type?) -> Bool {
        fatalError("WebServiceSwift.AlamofireBaseGateway: require override isSupportedRequest(request:rawDataForRestoreFromStorage:) function.")
    }
    
    /**
     Perform request to server. Result return as Alamofire.DataRequest or throw error. If return nil - require call `startAlamofireRequest()` or `data.completionWithError()` manually.
     
     If `queueForRequest != nil`, thread use from `queueForRequest`, else default thread (usually main).
     
     Use only one from case:
     1. Return Alamofire.DataRequest
     2. Throw error
     3. Perform startAlamofireRequest(:data:) and return nil. Usually used in async closures.
     4. Perform data.completionWithError() and return nil. Usually used in async closures.
     
     - Parameters:
        - requestId: Unique id for request. ID generated always unique for all Gateways and WebServices. Use for `canceledRequest()`.
        - data: Request data with completion closures (used this when return nil).
     
     - Throws: Error peroform request.
     - Returns: Alamofire request for `startAlamofireRequest()`. When nil - need manually perofrm `startAlamofireRequest()` or `data.completionWithError()`.
     */
    open func performRequest(requestId: UInt64, data: RequestData) throws -> Alamofire.DataRequest? {
        fatalError("WebServiceSwift.AlamofireBaseGateway: require override request(data:) function. You need use function startAlamofireRequest(:data:) when returned nil.")
    }
    
    /**
     Process data from server or store with rawData. Work in background thread.
     
     - Parameters:
         - request: Original request.
         - rawData: Type data from method `responseAlamofire()`. Usually binary Data.
         - fromStorage: If `true`: data from storage, else data from method `responseAlamofire()`.
     
     - Throws: Error validation or proccess data from server to end data. Data from server (also rawData) don't save to storage.
     - Returns: Result data for response.
     */
    open func dataProcessing(request: WebServiceBaseRequesting, rawData: Any, fromStorage: Bool) throws -> Any {
        fatalError("WebServiceSwift.AlamofireBaseGateway: require override dataProcessing(request:rawData:fromStorage:) function.")
    }
    
    
    /**
     Response pre processing and validation, return Raw data or throw error.
     
     Default implementation: without validation, return binary data (Data).
 
     - Parameters:
        - response: Alamofire response from server.
        - requestId: Unique id for request.
        - requestData: Data for request. Don't recomendation use closures.

     - Throws: Error validation data from server.
     - Returns: Return raw data from server.
     */
    open func responseAlamofire(_ response: Alamofire.DataResponse<Data>, requestId: UInt64, requestData: RequestData) throws -> Any {
        //Default implementation
        switch response.result {
        case .success(let data):
            return data
            
        case .failure(let error):
            throw error
        }
    }
    
    /**
     Preformed after canceled request. Can be overrided, default empty implementation.
     
     If `queueForRequest != nil`, thread use from `queueForRequest`, else default thread (usually main).
     
     - Parameters:
        - request: Alamofire request.
        - innerData: user data, used only in child classes.
        - requestId: Unique id for request.
     */
    open func canceledAlamofireRequest(_ request: Alamofire.DataRequest, innerData: Any?, requestId: UInt64) {
        
    }
    
    
    //MARK: - Helpers
    /**
     Start request, require always perform from `performRequest(requestId:data:)`, but auto performed startAlamofireRequest when request returned from `performRequest(requestId:data:)` and not require perofrm.
     
     - Parameters:
        = request: Alamofire request from `performRequest(requestId:data:)`.
        - requestId: Unique id for request.
        - data: Request data with completion closures.
     */
    public func startAlamofireRequest(_ request: Alamofire.DataRequest, requestId: UInt64, data: RequestData) {
        let task = TaskData(requestId: requestId, requestData: data, request: request)
        
        lock.synchronized {
            self.tasks[requestId] = task
        }
        
        task.request.responseData(queue: queueForDataProcessingFromStorage) { [weak self] response in
            if let sSelf = self {
                sSelf.lock.synchronized {
                    sSelf.tasks.removeValue(forKey: requestId)
                }
                
                do {
                    let result = try sSelf.responseAlamofire(response, requestId: requestId, requestData: data)
                    data.completionWithRawData(result)
                } catch {
                    data.completionWithError(error)
                }
            } else {
                data.completionWithError(WebServiceRequestError.gatewayInternal)
            }
        }
    }
    
    /// Find request data.
    public func requestData(forSessionTask sessionTask: URLSessionTask) -> (requestId: UInt64, data: RequestData)? {
        return lock.synchronized {
            for (requestId, taskData) in tasks {
                if taskData.request.task == sessionTask {
                    return (requestId, taskData.requestData)
                }
            }
            
            return nil
        }
    }
    
    /// Update request data. Usually changed innerData.
    public func updateRequestData(requestId: UInt64, data: RequestData) {
        lock.synchronized {
            tasks[requestId]?.requestData = data
        }
    }
    
    
    //MARK: - Private
    private struct TaskData {
        var requestId: UInt64
        var requestData: RequestData
        var request: Alamofire.DataRequest
    }
    
    private let lock = PThreadMutexLock()
    private var tasks = [UInt64: TaskData]()
    
    
    //MARK: Engine implementation
    public func performRequest(requestId: UInt64, request: WebServiceBaseRequesting, completionWithRawData: @escaping (Any) -> Void, completionWithError: @escaping (Error) -> Void) {
        do {
            let data = RequestData(request: request, completionWithRawData: completionWithRawData, completionWithError: completionWithError)
            if let af_request = try self.performRequest(requestId: requestId, data: data) {
                startAlamofireRequest(af_request, requestId: requestId, data: data)
            }
        } catch {
            if let error = error as? WebServiceRequestError {
                completionWithError(error)
            } else {
                completionWithError(WebServiceRequestError.invalidRequest(error))
            }
        }
    }
    
    open func canceledRequest(requestId: UInt64) {
        if let task: TaskData = lock.synchronized({ self.tasks.removeValue(forKey: requestId) }) {
            task.request.cancel()
            canceledAlamofireRequest(task.request, innerData: task.requestData.innerData, requestId: requestId)
        }
    }
}
