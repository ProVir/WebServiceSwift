//
//  WebServiceAlamofireBaseEngine.swift
//  WebServiceSwift 2.3.0
//
//  Created by ViR (Короткий Виталий) on 31.05.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation
import Alamofire


open class WebServiceAlamofireBaseEngine: WebServiceEngining {
    public let queueForRequest: DispatchQueue?
    public let queueForDataHandler: DispatchQueue? = nil
    public let queueForDataHandlerFromStorage: DispatchQueue? = DispatchQueue.global(qos: .default)
    
    public let useNetworkActivityIndicator: Bool
    
    public init(queueForRequest: DispatchQueue?, useNetworkActivityIndicator: Bool) {
        self.queueForRequest = queueForRequest
        self.useNetworkActivityIndicator = useNetworkActivityIndicator
    }
    
    
    private struct TaskData {
        var requestId: UInt64
        var requestData: RequestData
        var request: Alamofire.DataRequest
    }
    
    public struct RequestData {
        public var request: WebServiceBaseRequesting
        
        public var completionWithData: (Any) -> Void
        public var completionWithError: (Error) -> Void
        public var canceled: () -> Void
        
        public var innerData: Any?
        
        public init(request: WebServiceBaseRequesting,
                    completionWithData: @escaping (Any) -> Void,
                    completionWithError: @escaping (Error) -> Void,
                    canceled: @escaping () -> Void,
                    innerData: Any? = nil) {
            self.request = request
            self.completionWithData = completionWithData
            self.completionWithError = completionWithError
            self.canceled = canceled
            self.innerData = innerData
        }
    }
    
    
    private let lock = PThreadMutexLock()
    private var tasks = [UInt64: TaskData]()
    
    
    public func performRequest(requestId: UInt64, request: WebServiceBaseRequesting, completionWithData: @escaping (Any) -> Void, completionWithError: @escaping (Error) -> Void, canceled: @escaping () -> Void) {
        do {
            let data = RequestData(request: request, completionWithData: completionWithData, completionWithError: completionWithError, canceled: canceled)
            if let af_request = try self.performRequest(requestId: requestId, data: data) {
                startAlamofireRequest(af_request, requestId: requestId, data: data)
            }
        } catch {
            completionWithError(error)
        }
    }
    
    open func cancelRequest(requestId: UInt64) {
        if let task:TaskData = lock.synchronized({ self.tasks.removeValue(forKey: requestId) }) {
            task.request.cancel()
            task.requestData.canceled()
            
            canceledAlamofireRequest(task.request, requestId: requestId)
        }
    }
    
    
    
    //MARK: - Need Override
    open func isSupportedRequest(_ request: WebServiceBaseRequesting, rawDataTypeForRestoreFromStorage: Any.Type?) -> Bool {
        fatalError("WebServiceAlamofireBaseEngine: require override isSupportedRequest(request:rawDataForRestoreFromStorage:) function. ")
    }
    
    open func performRequest(requestId: UInt64, data: RequestData) throws -> Alamofire.DataRequest? {
        fatalError("WebServiceAlamofireBaseEngine: require override request(data:) function. You need use function startAlamofireRequest(:data:)")
    }
    
    open func dataHandler(request: WebServiceBaseRequesting, data: Any, isRawFromStorage: Bool) throws -> Any? {
        fatalError("WebServiceAlamofireBaseEngine: require override dataHandler(request:data:isRawFromStorage:) function. ")
    }
    
    
    //MARK: Can override
    open func canceledAlamofireRequest(_ request: Alamofire.DataRequest, requestId: UInt64) {
        
    }
    
    open func responseAlamofire(_ response: Alamofire.DataResponse<Data>, requestId: UInt64, requestData: RequestData) throws -> Any {
        //Default implementation
        switch response.result {
        case .success(let data):
            return data
            
        case .failure(let error):
            throw error
        }
    }
    
    
    
    //MARK: - Helper
    public func startAlamofireRequest(_ request: Alamofire.DataRequest, requestId: UInt64, data: RequestData) {
        let task = TaskData(requestId: requestId, requestData: data, request: request)
        
        lock.synchronized {
            self.tasks[requestId] = task
        }
        
        task.request.responseData(queue: queueForDataHandlerFromStorage) { [weak self] response in
            if let sSelf = self {
                sSelf.lock.synchronized {
                    sSelf.tasks.removeValue(forKey: requestId)
                }
                
                do {
                    let result = try sSelf.responseAlamofire(response, requestId: requestId, requestData: data)
                    data.completionWithData(result)
                } catch {
                    data.completionWithError(error)
                }
            } else {
                data.canceled()
            }
        }
    }
    
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
    
    public func updateRequestData(requestId: UInt64, data: RequestData) {
        lock.synchronized {
            tasks[requestId]?.requestData = data
        }
    }
    
}
