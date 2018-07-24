//
//  SiteWebServiceSimpleHandler.swift
//  WebServiceExample
//
//  Created by Короткий Виталий on 24.07.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation
import WebServiceSwift

struct SiteWebServiceSimpleHandler {
    static func decodeResponse(data: Data) throws -> String {
        if let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1251) {
            return text
        } else {
            throw WebServiceResponseError.invalidData
        }
    }
}


extension SiteWebServiceRequests.SiteSearch: WebServiceSimpleRequesting {
    func simpleRequest() throws -> URLRequest {
        return URLRequest(url: urlSite)
    }
    
    var simpleResponseType: WebServiceSimpleResponseType { return .binary }
    func simpleDecodeResponse(_ data: WebServiceSimpleResponseData) throws -> String {
        return try SiteWebServiceSimpleHandler.decodeResponse(data: data.binary)
    }
}

extension SiteWebServiceRequests.SiteMail: WebServiceSimpleRequesting {
    func simpleRequest() throws -> URLRequest {
        return URLRequest(url: urlSite)
    }
    
    var simpleResponseType: WebServiceSimpleResponseType { return .binary }
    func simpleDecodeResponse(_ data: WebServiceSimpleResponseData) throws -> String {
        return try SiteWebServiceSimpleHandler.decodeResponse(data: data.binary)
    }
}

extension SiteWebServiceRequests.SiteYouTube: WebServiceSimpleRequesting {
    func simpleRequest() throws -> URLRequest {
        return URLRequest(url: urlSite)
    }
    
    var simpleResponseType: WebServiceSimpleResponseType { return .binary }
    func simpleDecodeResponse(_ data: WebServiceSimpleResponseData) throws -> String {
        return try SiteWebServiceSimpleHandler.decodeResponse(data: data.binary)
    }
}

