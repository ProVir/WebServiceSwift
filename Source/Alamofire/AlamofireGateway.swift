//
//  AlamofireGateway.swift
//  WebServiceSwift 4.0.0
//
//  Created by Короткий Виталий (ViR) on 31.05.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation
import Alamofire

public protocol AlamofireGatewayHandler: class {
    /**
     Set callback closures from gateway. Default not save closures.

     - Parameters:
        - findRequestData: Closure for find request data in gateway used apple session task
        - updateInnerData: Closure for update innerData in gateway
     */
    func setup(findRequestData: @escaping (URLSessionTask) -> (requestId: UInt64, request: WebServiceBaseRequesting, innerData: Any?)?,
               updateInnerData:  @escaping (_ requestId: UInt64, _ innerData: Any?) -> Void)

    /**
     Asks whether the request supports this gateway.

     If `rawDataForRestoreFromStorage != nil`, after this method called `dataProcessing(request:rawData:fromStorage:)` method with `fromStorage = true`.

     - Parameters:
        - request: Request for test.
        - forDataProcessingFromStorage: If no nil - request restore raw data from storage with data.
     - Returns: If request support this gateway - return true.
     */
    func isSupportedRequest(_ request: WebServiceBaseRequesting, forDataProcessingFromStorage rawDataType: WebServiceStorageRawData.Type?) -> Bool

    /**
     Make request to server. Result return in completion closure.

     If `queueForRequest != nil`, thread use from `queueForRequest`, else default thread (usually main).

     - Parameters:
        - requestId: Unique id for request. ID generated always unique for all Gateways and WebServices. Used for `canceledRequest()`.
        - request: Original request with data.
        - completion: Need one perform with result - error or alamofire request.
     */
    func makeAlamofireRequest(requestId: UInt64, request: WebServiceBaseRequesting, completion: @escaping (AlamofireGateway.RequestResult) -> Void)

    /**
     Response processing and validation.

     - Parameters:
        - response: Alamofire response from server.
        - requestId: Unique id for request.
        - request: Original request.
        - innerData: Optional custom handler data.

     - Throws: Error validation data from server.
     - Returns: Return result from server.
     */
    func responseAlamofire(_ response: Alamofire.DataResponse<Data>, requestId: UInt64, request: WebServiceBaseRequesting, innerData: Any?) throws -> WebServiceGatewayResponse

    /**
     Preformed after canceled request. Default empty implementation.

     If `queueForRequest != nil`, thread use from `queueForRequest`, else default thread (usually main).

     - Parameters:
        - request: Alamofire request.
        - innerData: custom handler data.
        - requestId: Unique id for request.
     */
    func canceledAlamofireRequest(_ request: Alamofire.DataRequest, requestId: UInt64, innerData: Any?)

    /**
     Process raw data from storage. Work in background thread.

     - Parameters:
     - request: Original request.
     - rawData: Raw data from storage. Usually binary Data.

     - Throws: Error validation or proccess data from storage to result.
     - Returns: Result data for response.
     */
    func dataProcessingFromStorage(request: WebServiceBaseRequesting, rawData: WebServiceStorageRawData) throws -> Any
}

public extension AlamofireGatewayHandler {
    func setup(findRequestData: @escaping (URLSessionTask) -> (requestId: UInt64, request: WebServiceBaseRequesting, innerData: Any?)?,
               updateInnerData:  @escaping (_ requestId: UInt64, _ innerData: Any?) -> Void) { }

    func canceledAlamofireRequest(_ request: Alamofire.DataRequest, requestId: UInt64, innerData: Any?) { }
}

/// Gateway with support Alamofire.
open class AlamofireGateway: WebServiceGateway {
    public let queueForRequest: DispatchQueue?
    public let queueForDataProcessingFromStorage: DispatchQueue? = DispatchQueue.global(qos: .utility)
    public let useNetworkActivityIndicator: Bool

    private let queueForResponse = DispatchQueue.global(qos: .utility)
    private let handler: AlamofireGatewayHandler
    
    /**
     Constructor for gateway.
 
     - Parameters:
        - queueForRequest: Thread Dispatch Queue for `perofrmRequest()` and `cancelRequests()` methods.
        - useNetworkActivityIndicator: When `true`, showed networkActivityIndicator in statusBar when requests in process.
        - handler: Handler with api logic
    */
    public init(queueForRequest: DispatchQueue?, useNetworkActivityIndicator: Bool, handler: AlamofireGatewayHandler) {
        self.queueForRequest = queueForRequest
        self.useNetworkActivityIndicator = useNetworkActivityIndicator
        self.handler = handler

        handler.setup(
            findRequestData: { [weak self] in return self?.findRequestData(forSessionTask: $0) },
            updateInnerData: { [weak self] in self?.updateInnerData(requestId: $0, innerData: $1) }
        )
    }

    /// Result make request
    public enum RequestResult {
        case success(Alamofire.DataRequest, innerData: Any?)
        case failure(Error)
    }
    
    /// Request data with completion closures.
    public struct RequestData {
        public var request: WebServiceBaseRequesting
        
        /// User optional data, used only in child classes.
        public var innerData: Any?
        
        public init(request: WebServiceBaseRequesting,
                    innerData: Any? = nil) {
            self.request = request
            self.innerData = innerData
        }
    }

    // MARK: Gateway implementation
    open func isSupportedRequest(_ request: WebServiceBaseRequesting, forDataProcessingFromStorage rawDataType: WebServiceStorageRawData.Type?) -> Bool {
        return handler.isSupportedRequest(request, forDataProcessingFromStorage: rawDataType)
    }

    open func performRequest(requestId: UInt64, request: WebServiceBaseRequesting, completion: @escaping (Result<WebServiceGatewayResponse, Error>) -> Void) {
        handler.makeAlamofireRequest(requestId: requestId, request: request) { [weak self] result in
            guard let self = self else {
                completion(.failure(WebServiceRequestError.gatewayInternal))
                return
            }

            switch result {
            case let .success(af_request, innerData):
                self.startAlamofireRequest(af_request, requestId: requestId, request: request, innerData: innerData, completion: completion)

            case .failure(let error):
                if let error = error as? WebServiceRequestError {
                    completion(.failure(error))
                } else {
                    completion(.failure(WebServiceRequestError.invalidRequest(error)))
                }
            }
        }
    }

    open func canceledRequest(requestId: UInt64) {
        if let task: TaskData = lock.synchronized({ self.tasks.removeValue(forKey: requestId) }) {
            task.afRequest.cancel()
            handler.canceledAlamofireRequest(task.afRequest, requestId: requestId, innerData: task.innerData)
        }
    }

    open func dataProcessingFromStorage(request: WebServiceBaseRequesting, rawData: WebServiceStorageRawData) throws -> Any {
        return try handler.dataProcessingFromStorage(request: request, rawData: rawData)
    }
    
    // MARK: - Helpers
    public func findRequestData(forSessionTask sessionTask: URLSessionTask) -> (requestId: UInt64, request: WebServiceBaseRequesting, innerData: Any?)? {
        return lock.synchronized {
            for (requestId, taskData) in tasks {
                if taskData.afRequest.task == sessionTask {
                    return (requestId, taskData.request, taskData.innerData)
                }
            }
            
            return nil
        }
    }

    public func updateInnerData(requestId: UInt64, innerData: Any?) {
        lock.synchronized {
            tasks[requestId]?.innerData = innerData
        }
    }
    
    // MARK: - Private
    private struct TaskData {
        let requestId: UInt64
        let request: WebServiceBaseRequesting
        let afRequest: Alamofire.DataRequest

        var innerData: Any?
    }
    
    private let lock = PThreadMutexLock()
    private var tasks = [UInt64: TaskData]()

    private func startAlamofireRequest(_ afRequest: Alamofire.DataRequest, requestId: UInt64, request: WebServiceBaseRequesting, innerData: Any?, completion: @escaping (Result<WebServiceGatewayResponse, Error>) -> Void) {
        let task = TaskData(requestId: requestId, request: request, afRequest: afRequest, innerData: innerData)

        lock.synchronized {
            self.tasks[requestId] = task
        }

        task.afRequest.responseData(queue: queueForResponse) { [weak self] response in
            guard let self = self else {
                completion(.failure(WebServiceRequestError.gatewayInternal))
                return
            }

            self.lock.synchronized {
                self.tasks.removeValue(forKey: requestId)
            }

            let result = Result<WebServiceGatewayResponse, Error> {
                try self.handler.responseAlamofire(response, requestId: requestId, request: request, innerData: innerData)
            }
            completion(result)
        }
    }
}
