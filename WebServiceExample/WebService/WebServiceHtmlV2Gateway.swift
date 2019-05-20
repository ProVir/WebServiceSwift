//
//  WebServiceHtmlV2Gateway.swift
//  WebServiceExample
//
//  Created by Короткий Виталий on 25.07.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation
import WebServiceSwift
import Alamofire

///Gateway for get html data for URL.
class WebServiceHtmlV2Gateway: AlamofireBaseGateway {

    init() {
        super.init(queueForRequest: DispatchQueue.global(qos: .background), useNetworkActivityIndicator: true)
    }
    
    override func isSupportedRequest(_ request: WebServiceBaseRequesting, rawDataTypeForRestoreFromStorage: Any.Type?) -> Bool {
        return request is WebServiceHtmlRequesting
    }
    
    override func performRequest(requestId: UInt64, data: RequestData) throws -> Alamofire.DataRequest? {
        guard let url = (data.request as? WebServiceHtmlRequesting)?.url else {
            throw WebServiceRequestError.notSupportRequest
        }
        
        return Alamofire.request(url)
    }
    
    override func dataProcessing(request: WebServiceBaseRequesting, rawData: Any, fromStorage: Bool) throws -> Any {
        guard request is WebServiceHtmlRequesting, let binary = rawData as? Data else {
            throw WebServiceRequestError.notSupportDataProcessing
        }
        
        if let result = String(data: binary, encoding: .utf8) ?? String(data: binary, encoding: .windowsCP1251) {
            return result
        } else {
            throw WebServiceResponseError.invalidData(ParseResponseError.unknownTextEncoding)
        }
    }
}
