//
//  SiteWebServiceRequest.swift
//  WebServiceExample
//
//  Created by Короткий Виталий on 24.08.17.
//  Copyright © 2017 ProVir. All rights reserved.
//

import Foundation
import WebServiceSwift
import Alamofire

extension SiteWebServiceRequest {
    var urlSite: URL {
        switch self {
        case .siteSearch(let type, domain: let domain):
            return type.baseUrl(domain: domain)
            
        case .siteMail(let type):
            return type.baseUrl()
            
        case .siteYouTube:
            return URL(string: "https://www.youtube.com/?gl=RU&hl=ru")!
        }
    }
    
    func decodeResponse(data: Data) throws -> String {
        if let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1251) {
            return text
        } else {
            throw WebServiceResponseError.invalidData
        }
    }
}


/// As HTML Request - Support WebServiceHTMLEndpoint with concrete URL query.
extension SiteWebServiceRequest: WebServiceHtmlRequesting {
    var url: URL { return urlSite }
}

extension SiteWebServiceRequest: WebServiceSimpleRequesting {
    func simpleRequest() throws -> URLRequest {
        return URLRequest(url: urlSite)
    }
    
    var simpleResponseType: WebServiceSimpleResponseType { return .binary }
    func simpleDecodeResponse(_ data: WebServiceSimpleResponseData) throws -> String {
        return try decodeResponse(data: data.binary)
    }
}

extension SiteWebServiceRequest: WebServiceAlamofireRequesting {
    func afRequest(sessionManager: SessionManager) throws -> DataRequest {
        return sessionManager.request(urlSite)
    }
    
    var afResponseType: WebServiceAlamofireResponseType { return .binary }
    func afDecodeResponse(_ data: WebServiceAlamofireResponseData) throws -> String {
        return try decodeResponse(data: data.binary)
    }
}


//MARK: Store support
extension SiteWebServiceRequest: WebServiceRequestRawFileStoring {
    var identificatorForFileStorage: String? {
        switch self {
        case .siteSearch(let type, domain: let domain):
            return type.rawValue + ".\(domain)"

        case .siteMail(let type):
            return type.rawValue

        case .siteYouTube:
            return "siteYouTube"
        }
    }
}

/*
extension SiteWebServiceRequest: WebServiceRequestValueFileStoring {
    var identificatorForFileStorage: String? {
        switch self {
        case .siteSearch(let type, domain: let domain):
            return type.rawValue + ".\(domain)"
            
        case .siteMail(let type):
            return type.rawValue
            
        case .siteYouTube:
            return "siteYouTube"
        }
    }
    
    func writeDataToFileStorage(value: String) -> Data? {
        return value.data(using: String.Encoding.utf8)
    }
    
    func readDataFromFileStorage(data: Data) throws -> String? {
        return String(data: data, encoding: String.Encoding.utf8)
    }
}
*/

extension SiteWebServiceRequest: WebServiceMockRequesting {
    var isSupportedRequestForMock: Bool { return true }
    var mockTimeWait: TimeInterval? { return 3 }
    
    var mockHelperIdentifier: String? { return "template_html" }
    func mockCreateHelper() -> Any? {
        return "<html><body>%[BODY]%</body></html>"
    }
    
    func mockResponseHandler(helper: Any?) throws -> String {
        if let template = helper as? String {
            return template.replacingOccurrences(of: "%[BODY]%", with: "<b>Hello world!</b>")
        } else {
            throw WebServiceResponseError.invalidData
        }
    }
}
