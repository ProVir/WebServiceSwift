//
//  WebServiceSimpleGateway.swift
//  WebServiceSwift 4.0.0
//
//  Created by Короткий Виталий (ViR) on 01.06.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation

// MARK: Request

/// Base protocol for request use WebServiceSimpleGateway
public protocol WebServiceSimpleBaseRequesting {
    /// Create real request to server
    func simpleRequest() throws -> URLRequest
    
    /// Response type (binary or json) for decode response.
    var simpleResponseType: WebServiceSimpleResponseType { get }
    
    /// Decode response to value. Used `data.binary` or `data.json` dependency from `simpleResponseType` parameter. Perofrm in background thread.
    func simpleBaseDecodeResponse(_ data: WebServiceSimpleResponseData) throws -> Any
}

public protocol WebServiceSimpleRequesting: WebServiceSimpleBaseRequesting, WebServiceRequesting {
    /// Decode response to value. Used `data.binary` or `data.json` dependency from `simpleResponseType` parameter. Perofrm in background thread.
    func simpleDecodeResponse(_ data: WebServiceSimpleResponseData) throws -> ResultType
}

public extension WebServiceSimpleRequesting {
    func simpleBaseDecodeResponse(_ data: WebServiceSimpleResponseData) throws -> Any {
        return try simpleDecodeResponse(data)
    }
}

// MARK: Response
/// Response type to require for decoder
public enum WebServiceSimpleResponseType {
    case binary
    case json
}

/// Response data for decoder
public enum WebServiceSimpleResponseData {
    case binary(Data)
    case json(Any)
    
    /// Get binary data for decoder
    public func binary() throws -> Data {
        if case let .binary(value) = self {
            return value
        } else {
            throw WebServiceRequestError.gatewayInternal
        }
    }
    
    /// Get json data for decoder
    public func json() throws -> Any {
        if case let .json(value) = self {
            return value
        } else {
            throw WebServiceRequestError.gatewayInternal
        }
    }
}


// MARK: Auto decoders
/// Protocol for enable auto implementation response decoder (simpleResponseType and simpleDecodeResponse) for certain result types.
protocol WebServiceSimpleAutoDecoder: WebServiceRequesting { }

/// Support AutoDecoder for request, when ignored result data from server (ResultType = Void).
extension WebServiceSimpleAutoDecoder where ResultType == Void {
    var simpleResponseType: WebServiceSimpleResponseType { return .binary }
    func simpleDecodeResponse(_ data: WebServiceSimpleResponseData) throws -> Void {
        return Void()
    }
}

/// Support AutoDecoder for binary reslt type (ResultType = Data)
extension WebServiceSimpleAutoDecoder where ResultType == Data {
    var simpleResponseType: WebServiceSimpleResponseType { return .binary }
    func simpleDecodeResponse(_ data: WebServiceSimpleResponseData) throws -> Data {
        return try data.binary()
    }
}


// MARK: Gateway
/// Simple HTTP Gateway (use URLSession)
public class WebServiceSimpleGateway: WebServiceGateway {
    public let queueForRequest: DispatchQueue?
    public let queueForDataProcessingFromStorage: DispatchQueue? = DispatchQueue.global(qos: .utility)
    public let useNetworkActivityIndicator: Bool
    
    /**
     Simple HTTP Gateway used URLSession constructor.
     
     - Parameters:
         - session: URLSession for use, default use shared.
         - queueForRequest: Thread Dispatch Queue for `perofrmRequest()` and `cancelRequests()` methods.
         - useNetworkActivityIndicator: When `true`, showed networkActivityIndicator in statusBar when requests in process.
    */
    public init(session: URLSession = URLSession.shared, queueForRequest: DispatchQueue? = nil, useNetworkActivityIndicator: Bool = true) {
        self.session = session
        self.queueForRequest = queueForRequest
        self.useNetworkActivityIndicator = useNetworkActivityIndicator
    }
    
    
    // MARK: Gateway implementation
    public func isSupportedRequest(_ request: WebServiceBaseRequesting, forDataProcessingFromStorage rawDataType: WebServiceStorageRawData.Type?) -> Bool {
        return request is WebServiceSimpleBaseRequesting
    }
    
    public func performRequest(requestId: UInt64, request: WebServiceBaseRequesting, completion: @escaping (Result<WebServiceGatewayResponse, Error>) -> Void) {
        guard let request = request as? WebServiceSimpleBaseRequesting else {
            completion(.failure(WebServiceRequestError.notSupportRequest))
            return
        }
        
        do {
            //Create Task
            let urlRequest = try request.simpleRequest()
            
            let task = session.dataTask(with: urlRequest) { [weak self] (data, response, error) in
                guard let self = self else {
                    completion(.failure(WebServiceRequestError.gatewayInternal))
                    return
                }
                
                // Remove from queue
                let contain = self.lock.synchronized {
                    self.tasks.removeValue(forKey: requestId) != nil
                }
                
                if !contain { return }
                
                if let data = data {
                    //Validation data for http status code
                    if let response = response as? HTTPURLResponse, response.statusCode >= 300 {
                        completion(.failure(WebServiceResponseError.httpStatusCode(response.statusCode)))
                    } else {
                        do {
                            let result = try self.dataProcessing(request: request, binary: data)
                            completion(.success(.init(result: result, rawDataForStorage: data)))
                        } catch {
                            completion(.failure(error))
                        }
                    }
                } else if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.failure(WebServiceRequestError.gatewayInternal))
                }
            }
            
            //Run task
            let taskData = TaskData(requestId: requestId, task: task)
            lock.synchronized {
                self.tasks[requestId] = taskData
            }
            
            task.resume()
            
        } catch {
            completion(.failure(WebServiceRequestError.invalidRequest(error)))
        }
    }
    
    public func canceledRequest(requestId: UInt64) {
        if let task: TaskData = lock.synchronized({ self.tasks.removeValue(forKey: requestId) }) {
            task.task.cancel()
        }
    }
    
    public func dataProcessingFromStorage(request: WebServiceBaseRequesting, rawData: WebServiceStorageRawData) throws -> Any {
        guard let binary = rawData as? Data, let request = request as? WebServiceSimpleBaseRequesting else {
            throw WebServiceRequestError.notSupportDataProcessing
        }
        
        return try dataProcessing(request: request, binary: binary)
    }
    
    // MARK: - Private
    private struct TaskData {
        var requestId: UInt64
        var task: URLSessionDataTask
    }
    
    private let session: URLSession
    
    private let lock = PThreadMutexLock()
    private var tasks: [UInt64: TaskData] = [:]

    private func dataProcessing(request: WebServiceSimpleBaseRequesting, binary: Data) throws -> Any {
        switch request.simpleResponseType {
        case .binary:
            return try request.simpleBaseDecodeResponse(WebServiceSimpleResponseData.binary(binary))

        case .json:
            let jsonData = try JSONSerialization.jsonObject(with: binary, options: [])
            return try request.simpleBaseDecodeResponse(WebServiceSimpleResponseData.json(jsonData))
        }
    }
}
