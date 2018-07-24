//
//  SiteWebServiceAlamofireHandler.swift
//  WebServiceExample
//
//  Created by Короткий Виталий on 25.07.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation
import WebServiceSwift
import Alamofire


struct SiteWebServiceAlamofireHandler {
    static func decodeResponse(data: Data) throws -> String {
        if let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1251) {
            return text
        } else {
            throw WebServiceResponseError.invalidData
        }
    }
}


extension SiteWebServiceRequests.SiteSearch: WebServiceAlamofireRequesting {
    func afRequest(sessionManager: SessionManager) throws -> DataRequest {
        return sessionManager.request(urlSite)
    }
    
    var afResponseType: WebServiceAlamofireResponseType { return .binary }
    func afDecodeResponse(_ data: WebServiceAlamofireResponseData) throws -> String {
        return try SiteWebServiceAlamofireHandler.decodeResponse(data: data.binary)
    }
}

extension SiteWebServiceRequests.SiteMail: WebServiceAlamofireRequesting {
    func afRequest(sessionManager: SessionManager) throws -> DataRequest {
        return sessionManager.request(urlSite)
    }
    
    var afResponseType: WebServiceAlamofireResponseType { return .binary }
    func afDecodeResponse(_ data: WebServiceAlamofireResponseData) throws -> String {
        return try SiteWebServiceAlamofireHandler.decodeResponse(data: data.binary)
    }
}

extension SiteWebServiceRequests.SiteYouTube: WebServiceAlamofireRequesting {
    func afRequest(sessionManager: SessionManager) throws -> DataRequest {
        return sessionManager.request(urlSite)
    }
    
    var afResponseType: WebServiceAlamofireResponseType { return .binary }
    func afDecodeResponse(_ data: WebServiceAlamofireResponseData) throws -> String {
        return try SiteWebServiceAlamofireHandler.decodeResponse(data: data.binary)
    }
}
