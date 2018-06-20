//
//  WebServiceHtmlEndpoint.swift
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


///Endpoint for get html data for URL.
class WebServiceHtmlEndpoint: WebServiceEndpoint {
    let queueForRequest: DispatchQueue? = DispatchQueue.global(qos: .background)
    let queueForDataHandler: DispatchQueue? = nil
    let queueForDataHandlerFromStorage: DispatchQueue? = DispatchQueue.global(qos: .default)
    let useNetworkActivityIndicator = true
    
    func isSupportedRequest(_ request: WebServiceBaseRequesting, rawDataTypeForRestoreFromStorage: Any.Type?) -> Bool {
        return request is WebServiceHtmlRequesting
    }
    
    func performRequest(requestId: UInt64, request: WebServiceBaseRequesting,
                        completionWithRawData: @escaping (_ data: Any) -> Void,
                        completionWithError: @escaping (_ error: Error) -> Void) {
        
        guard let url = (request as? WebServiceHtmlRequesting)?.url else {
            completionWithError(WebServiceRequestError.notSupportRequest)
            return
        }

        Alamofire.request(url).responseData { response in
            switch response.result {
            case .success(let data):
                completionWithRawData(data)
                
            case .failure(let error):
                completionWithError(error)
            }
        }
    }
    
    func canceledRequest(requestId: UInt64) { /* Don't support */ }
    
    func dataProcessing(request: WebServiceBaseRequesting, rawData: Any, fromStorage: Bool) throws -> Any? {
        guard request is WebServiceHtmlRequesting, let data = rawData as? Data else {
            throw WebServiceRequestError.notSupportDataHandler
        }

        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1251)
    }
}

