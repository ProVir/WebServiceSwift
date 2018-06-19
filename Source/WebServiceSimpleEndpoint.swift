//
//  WebServiceSimpleEndpoint.swift
//  WebServiceSwift 3.0.0
//
//  Created by Короткий Виталий (ViR) on 01.06.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation

//MARK: Request
public protocol WebServiceSimpleBaseRequesting {
    func simpleRequest() throws -> URLRequest
    
    var simpleResponseType: WebServiceSimpleResponseType { get }
    func simpleBaseDecodeResponse(_ data: WebServiceSimpleResponseData) throws -> Any?
}

public protocol WebServiceSimpleRequesting: WebServiceSimpleBaseRequesting, WebServiceRequesting {
    func simpleDecodeResponse(_ data: WebServiceSimpleResponseData) throws -> ResultType
}

public extension WebServiceSimpleRequesting {
    func simpleBaseDecodeResponse(_ data: WebServiceSimpleResponseData) throws -> Any? {
        return try simpleDecodeResponse(data)
    }
}

//MARK: Response
public enum WebServiceSimpleResponseType {
    case binary
    case json
}

public struct WebServiceSimpleResponseData {
    //Only one is not null
    public let binary: Data!
    public let json: Any!
    
    public init(binary: Data) {
        self.binary = binary
        self.json = nil
    }
    
    public init(json: Any) {
        self.json = json
        self.binary = nil
    }
}

//MARK: Auto decoders
protocol WebServiceSimpleAutoDecoder: WebServiceRequesting { }

extension WebServiceSimpleAutoDecoder where ResultType == Void {
    var simpleResponseType: WebServiceSimpleResponseType { return .binary }
    func simpleDecodeResponse(_ data: WebServiceSimpleResponseData) throws -> Void {
        return Void()
    }
}

extension WebServiceSimpleAutoDecoder where ResultType == Data {
    var simpleResponseType: WebServiceSimpleResponseType { return .binary }
    func simpleDecodeResponse(_ data: WebServiceSimpleResponseData) throws -> Data {
        return data.binary
    }
}


//MARK: Endpoint
public class WebServiceSimpleEndpoint: WebServiceEndpoint {
    public let queueForRequest: DispatchQueue?
    public let queueForDataHandler: DispatchQueue? = nil
    public let queueForDataHandlerFromStorage: DispatchQueue? = DispatchQueue.global(qos: .default)
    public let useNetworkActivityIndicator: Bool
    
    private let session: URLSession
    
    private let lock = PThreadMutexLock()
    private var tasks: [UInt64: TaskData] = [:]
    
    public init(session: URLSession = URLSession.shared, queueForRequest: DispatchQueue? = nil, useNetworkActivityIndicator: Bool = true) {
        self.session = session
        self.queueForRequest = queueForRequest
        self.useNetworkActivityIndicator = useNetworkActivityIndicator
    }
    
    public func isSupportedRequest(_ request: WebServiceBaseRequesting, rawDataTypeForRestoreFromStorage: Any.Type?) -> Bool {
        return request is WebServiceSimpleBaseRequesting
    }
    
    public func performRequest(requestId: UInt64, request: WebServiceBaseRequesting, completionWithData: @escaping (Any) -> Void, completionWithError: @escaping (Error) -> Void, canceled: @escaping () -> Void) {
        guard let request = request as? WebServiceSimpleBaseRequesting else {
            completionWithError(WebServiceRequestError.notSupportRequest)
            return
        }
        
        do {
            let urlRequest = try request.simpleRequest()
            
            let task = session.dataTask(with: urlRequest) { [weak self] (data, response, error) in
                guard let sSelf = self else {
                    canceled()
                    return
                }
                
                let containt = sSelf.lock.synchronized {
                    sSelf.tasks.removeValue(forKey: requestId) != nil
                }
                
                if !containt { return }
                
                if let data = data {
                    if let response = response as? HTTPURLResponse, response.statusCode >= 300 {
                        completionWithError(WebServiceResponseError.httpStatusCode(response.statusCode))
                    } else {
                        completionWithData(data)
                    }
                    
                } else if let error = error {
                    completionWithError(error)
                } else {
                    canceled()
                }
            }
            
            let taskData = TaskData(requestId: requestId, task: task, canceled: canceled)
            lock.synchronized {
                self.tasks[requestId] = taskData
            }
            
            task.resume()
            
        } catch {
            completionWithError(error)
        }
    }
    
    public func cancelRequest(requestId: UInt64) {
        if let task: TaskData = lock.synchronized({ self.tasks.removeValue(forKey: requestId) }) {
            task.task.cancel()
            task.canceled()
        }
    }
    
    public func dataHandler(request: WebServiceBaseRequesting, data: Any, isRawFromStorage: Bool) throws -> Any? {
        guard let binary = data as? Data, let request = request as? WebServiceSimpleBaseRequesting else {
            throw WebServiceRequestError.notSupportDataHandler
        }
        
        switch request.simpleResponseType {
        case .binary:
            return try request.simpleBaseDecodeResponse(WebServiceSimpleResponseData(binary: binary))
            
        case .json:
            let jsonData = try JSONSerialization.jsonObject(with: binary, options: [])
            return try request.simpleBaseDecodeResponse(WebServiceSimpleResponseData(json: jsonData))
        }
    }
    
    //MARK: - Private
    private struct TaskData {
        var requestId: UInt64
        var task: URLSessionDataTask
        
        var canceled: () -> Void
    }
}
