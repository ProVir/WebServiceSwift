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
            throw WebServiceResponseError.invalidData(ParseResponseError.unknownTextEncoding)
        }
    }
}


extension SiteWebServiceRequests.SiteSearch: AlamofireSimpleRequesting {
    func afRequest(sessionManager: SessionManager) throws -> DataRequest {
        return sessionManager.request(urlSite)
    }
    
    var afResponseType: AlamofireSimpleResponseType { return .binary }
    func afDecodeResponse(_ data: AlamofireSimpleResponseData) throws -> String {
        return try SiteWebServiceAlamofireHandler.decodeResponse(data: data.binary)
    }
}

extension SiteWebServiceRequests.SiteMail: AlamofireSimpleRequesting {
    func afRequest(sessionManager: SessionManager) throws -> DataRequest {
        return sessionManager.request(urlSite)
    }
    
    var afResponseType: AlamofireSimpleResponseType { return .binary }
    func afDecodeResponse(_ data: AlamofireSimpleResponseData) throws -> String {
        return try SiteWebServiceAlamofireHandler.decodeResponse(data: data.binary)
    }
}

extension SiteWebServiceRequests.SiteYouTube: AlamofireSimpleRequesting {
    func afRequest(sessionManager: SessionManager) throws -> DataRequest {
        return sessionManager.request(urlSite)
    }
    
    var afResponseType: AlamofireSimpleResponseType { return .binary }
    func afDecodeResponse(_ data: AlamofireSimpleResponseData) throws -> String {
        return try SiteWebServiceAlamofireHandler.decodeResponse(data: data.binary)
    }
}
