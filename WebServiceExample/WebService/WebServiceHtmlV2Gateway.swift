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

/// Gateway handler for get html data for URL.
class WebServiceHtmlV2GatewayHandler: AlamofireGatewayHandler {
    static func makeGateway() -> AlamofireGateway {
        return .init(queueForRequest: DispatchQueue.global(qos: .utility), useNetworkActivityIndicator: true, handler: WebServiceHtmlV2GatewayHandler())
    }

    func isSupportedRequest(_ request: WebServiceBaseRequesting, rawDataTypeForRestoreFromStorage: Any.Type?) -> Bool {
        return request is WebServiceHtmlRequesting
    }

    func makeAlamofireRequest(requestId: UInt64, request: WebServiceBaseRequesting, completion: @escaping (AlamofireGateway.RequestResult) -> Void) {
        do {
            completion(.success(try makeAlamofireRequest(requestId: requestId, request: request), innerData: nil))
        } catch {
            completion(.failure(error))
        }
    }

    private func makeAlamofireRequest(requestId: UInt64, request: WebServiceBaseRequesting) throws -> Alamofire.DataRequest {
        guard let url = (request as? WebServiceHtmlRequesting)?.url else {
            throw WebServiceRequestError.notSupportRequest
        }

        return AF.request(url)
    }

    func dataProcessing(request: WebServiceBaseRequesting, rawData: Any, fromStorage: Bool) throws -> Any {
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
