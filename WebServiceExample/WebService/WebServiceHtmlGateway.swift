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
    let queueForRequest: DispatchQueue? = DispatchQueue.global(qos: .utility)
    let queueForDataProcessingFromStorage: DispatchQueue? = DispatchQueue.global(qos: .utility)
    let useNetworkActivityIndicator = true

    func isSupportedRequest(_ request: WebServiceBaseRequesting, forDataProcessingFromStorage rawDataType: WebServiceStorageRawData.Type?) -> Bool {
        return request is WebServiceHtmlRequesting
    }
    
    func performRequest(requestId: UInt64, request: WebServiceBaseRequesting, completion: @escaping (Result<WebServiceGatewayResponse, Error>) -> Void) {
        guard let url = (request as? WebServiceHtmlRequesting)?.url else {
            completion(.failure(WebServiceRequestError.notSupportRequest))
            return
        }

        AF.request(url).responseData { [weak self] response in
            guard let self = self else {
                completion(.failure(WebServiceRequestError.gatewayInternal))
                return
            }

            switch response.result {
            case .success(let binary):
                let result = Result<WebServiceGatewayResponse, Error> {
                    try self.validateResponse(response)
                    let data = try self.dataProcessing(binary: binary)
                    return .init(result: data, rawDataForStorage: binary)
                }
                completion(result)

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func canceledRequest(requestId: UInt64) { /* Don't support */ }

    func dataProcessingFromStorage(request: WebServiceBaseRequesting, rawData: WebServiceStorageRawData) throws -> Any {
        guard request is WebServiceHtmlRequesting, let binary = rawData as? Data else {
            throw WebServiceRequestError.notSupportDataProcessing
        }

        return try dataProcessing(binary: binary)
    }

    private func validateResponse(_ response: DataResponse<Data>) throws {
        if let httpCode = response.response?.statusCode, httpCode >= 300 {
            throw WebServiceResponseError.httpStatusCode(httpCode)
        }
    }
    
    private func dataProcessing(binary: Data) throws -> Any {
        return String(data: binary, encoding: .utf8) ?? String(data: binary, encoding: .windowsCP1251) ?? ""
    }
}

