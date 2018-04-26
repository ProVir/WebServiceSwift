//
//  WebServiceMockEngine.swift
//  WebServiceSwift 2.2.0
//
//  Created by ViR (Короткий Виталий) on 12.03.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation


//MARK: Mock Request
public protocol WebServiceMockRequesting: WebServiceBaseRequesting {
    var isSupportedRequest:Bool { get }
    
    var timeWait:TimeInterval? { get }
    
    var helperIdentifier:String? { get }
    func createHelper(forIdentifier identifier:String) -> Any?
    
    func responseHandler(helper:Any?) throws -> Any?
}

public extension WebServiceMockRequesting {
    var isSupportedRequest:Bool { return true }
    
    var timeWait:TimeInterval? { return nil }
    
    var helperIdentifier:String? { return nil }
    func createHelper(forIdentifier identifier:String) -> Any? { return nil }
}


//MARK: Mock Engine
public class WebServiceMockEngine: WebServiceEngining {
    struct RequestItem {
        var workItem:DispatchWorkItem
        var canceled:() -> Void
    }
    
    public let queueForRequest: DispatchQueue? = nil
    public let queueForDataHandler: DispatchQueue? = nil
    public let queueForDataHandlerFromStorage: DispatchQueue? = nil
    public let useNetworkActivityIndicator = false
    
    
    var helpersArray = [String : Any]()
    var requests = [UInt64 : RequestItem]()
    
    public init() { }
    
    public func isSupportedRequest(_ request: WebServiceBaseRequesting, rawDataTypeForRestoreFromStorage: Any.Type?) -> Bool {
        return rawDataTypeForRestoreFromStorage == nil && ((request as? WebServiceMockRequesting)?.isSupportedRequest ?? false)
    }
    
    public func performRequest(requestId: UInt64, request: WebServiceBaseRequesting, completionWithData: @escaping (Any) -> Void, completionWithError: @escaping (Error) -> Void, canceled: @escaping () -> Void) {
        
        guard let request = request as? WebServiceMockRequesting else {
            completionWithError(WebServiceRequestError.notSupportRequest)
            return
        }
        
        
        //Helper Object
        let helper:Any?
        if let identifier = request.helperIdentifier {
            if let obj = helpersArray[identifier] {
                helper = obj
            } else if let obj = request.createHelper(forIdentifier: identifier) {
                helpersArray[identifier] = obj
                helper = obj
            } else {
                helper = nil
            }
        } else {
            helper = nil
        }
        
        
        //Request
        let workItem =  DispatchWorkItem { [weak self] in
            self?.requests.removeValue(forKey: requestId)
            
            do {
                let data = try request.responseHandler(helper: helper) ?? NSNull()
                completionWithData(data)
            } catch {
                completionWithError(error)
            }
        }
        
        requests[requestId] = RequestItem(workItem: workItem, canceled: canceled)
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + (request.timeWait ?? 0), execute: workItem)
    }
    
    public func cancelRequest(requestId: UInt64) {
        if let requestItem = requests[requestId] {
            requests.removeValue(forKey: requestId)
            requestItem.canceled()
        }
    }
    
    public func dataHandler(request: WebServiceBaseRequesting, data: Any, isRawFromStorage: Bool) throws -> Any? {
        if isRawFromStorage { return nil }
        else if data is NSNull { return nil }
        else { return data }
    }
}


