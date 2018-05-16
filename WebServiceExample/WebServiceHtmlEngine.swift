//
//  WebServiceHtmlEngine.swift
//  WebServiceExample
//
//  Created by Короткий Виталий on 24.08.17.
//  Copyright © 2017 ProVir. All rights reserved.
//

import Foundation
import WebServiceSwift
import Alamofire

///Base protocol for requests for get html data for URL.
protocol WebServiceHtmlRequesting: WebServiceBaseRequesting {
    var url: URL { get }
}


///Engine for get html data for URL.
class WebServiceHtmlEngine: WebServiceEngining {
    let queueForRequest:DispatchQueue? = DispatchQueue.global(qos: .background)
    let queueForDataHandler:DispatchQueue? = nil
    let queueForDataHandlerFromStorage:DispatchQueue? = DispatchQueue.global(qos: .default)
    let useNetworkActivityIndicator = false
    
    func isSupportedRequest(_ request: WebServiceBaseRequesting, rawDataTypeForRestoreFromStorage: Any.Type?) -> Bool {
        return request is WebServiceHtmlRequesting
    }
    
    func performRequest(requestId:UInt64, request:WebServiceBaseRequesting,
                        completionWithData:@escaping (_ data:Any) -> Void,
                        completionWithError:@escaping (_ error:Error) -> Void,
                        canceled:@escaping () -> Void) {
        
        guard let url = (request as? WebServiceHtmlRequesting)?.url else {
            completionWithError(WebServiceRequestError.notSupportRequest)
            return
        }

        Alamofire.request(url).responseData { response in
            switch response.result {
            case .success(let data):
                completionWithData(data)
                
            case .failure(let error):
                completionWithError(error)
            }
        }
    }
    
    func cancelRequest(requestId: UInt64) { /* Don't support */ }
    
    func dataHandler(request:WebServiceBaseRequesting, data:Any, isRawFromStorage:Bool) throws -> Any? {
        guard request is WebServiceHtmlRequesting, let data = data as? Data else {
            throw WebServiceRequestError.notSupportDataHandler
        }

        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1251)
    }
}

