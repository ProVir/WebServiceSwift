//
//  WebServiceHtmlGateway.swift
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

///Gateway for get html data for URL.
class WebServiceHtmlGateway: WebServiceGateway {
    let queueForRequest: DispatchQueue? = DispatchQueue.global(qos: .background)
    let queueForDataProcessing: DispatchQueue? = nil
    let queueForDataProcessingFromStorage: DispatchQueue? = DispatchQueue.global(qos: .background)
    let useNetworkActivityIndicator = true
    
    /// Data from server as raw, used only as example
    struct ServerData: WebServiceRawDataSource {
        let statusCode: Int
        let binary: Data
        
        var binaryRawData: Data? { return binary }
    }
    
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
                completionWithRawData(ServerData(statusCode: response.response?.statusCode ?? 0,
                                                 binary: data))
                
            case .failure(let error):
                completionWithError(error)
            }
        }
    }
    
    func canceledRequest(requestId: UInt64) { /* Don't support */ }
    
    func dataProcessing(request: WebServiceBaseRequesting, rawData: Any, fromStorage: Bool) throws -> Any {
        guard request is WebServiceHtmlRequesting else {
            throw WebServiceRequestError.notSupportDataProcessing
        }
        
        let binary: Data
        if let data = rawData as? Data {
            binary = data
        } else if let data = rawData as? ServerData {
            binary = data.binary
        } else {
            throw WebServiceRequestError.notSupportDataProcessing
        }

        return String(data: binary, encoding: .utf8) ?? String(data: binary, encoding: .windowsCP1251) ?? ""
    }
}

