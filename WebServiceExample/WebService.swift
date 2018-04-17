//
//  WebService.swift
//  WebServiceExample
//
//  Created by Короткий Виталий on 24.08.17.
//  Copyright © 2017 ProVir. All rights reserved.
//

import Foundation
import WebServiceSwift
import Alamofire


extension WebService {
    
    convenience init() {
        let engine = WebServiceSitesEngine()
        
        var storages:[WebServiceStoraging] = []
        if let storage = WebServiceSimpleStore() {
            storages.append(storage)
        }
        
        self.init(engines: [engine], storages:storages)
    }
    
    static var `default`: WebService {
        return WebServiceStatic.default
    }
}

private struct WebServiceStatic {
    static let `default` = WebService()
}



class WebServiceSitesEngine: WebServiceEngining {
    
    let queueForRequest:DispatchQueue? = DispatchQueue.global(qos: .background)
    let queueForDataHandler:DispatchQueue? = nil
    let queueForDataHandlerFromStorage:DispatchQueue? = DispatchQueue.global(qos: .default)
    let useNetworkActivityIndicator = false
    
    func isSupportedRequest(_ request: WebServiceRequesting, rawDataForRestoreFromStorage: Any?) -> Bool {
        return request is SiteWebServiceRequest
    }

    
    func request(requestId:UInt64, request:WebServiceRequesting,
                 completionWithData:@escaping (_ data:Any) -> Void,
                 completionWithError:@escaping (_ error:Error) -> Void,
                 canceled:@escaping () -> Void) {
        
        guard let method = request as? SiteWebServiceRequest else {
            completionWithError(WebServiceRequestError.notSupportRequest)
            return
        }

        Alamofire.request(method.url).responseData { response in
            switch response.result {
            case .success(let data):
                completionWithData(data)
                
            case .failure(let error):
                completionWithError(error)
            }
        }
    }

    
    func cancelRequest(requestId: UInt64) {
        
    }
    
    
    func dataHandler(request:WebServiceRequesting, data:Any, isRawFromStorage:Bool) throws -> Any? {
        guard request is SiteWebServiceRequest, let data = data as? Data else {
            throw WebServiceRequestError.notSupportDataHandler
        }

        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1251)
    }
    
}

