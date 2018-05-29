//
//  SiteWebServiceRequest.swift
//  WebServiceExample
//
//  Created by Короткий Виталий on 24.08.17.
//  Copyright © 2017 ProVir. All rights reserved.
//

import Foundation
import WebServiceSwift


/// As HTML Request - Support WebServiceHTMLEngine with concrete URL query.
extension SiteWebServiceRequest: WebServiceHtmlRequesting {
    var url: URL {
        switch self {
        case .siteSearch(let type, domain: let domain):
            return type.baseUrl(domain: domain)
            
        case .siteMail(let type):
            return type.baseUrl()
            
        case .siteYouTube:
            return URL(string: "https://www.youtube.com/?gl=RU&hl=ru")!
        }
    }
}


//MARK: Store support
extension SiteWebServiceRequest: WebServiceRequestRawStoring {
    var identificatorForStorage: String? {
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
extension SiteWebServiceRequest: WebServiceRequestValueStoring {
    var identificatorForStorage: String? {
        switch self {
        case .siteSearch(let type, domain: let domain):
            return type.rawValue + ".\(domain)"
            
        case .siteMail(let type):
            return type.rawValue
            
        case .siteYouTube:
            return "siteYouTube"
        }
    }
    
    func writeDataToStorage(value: String) -> Data? {
        return value.data(using: String.Encoding.utf8)
    }
    
    func readDataFromStorage(data: Data) throws -> String? {
        return String(data: data, encoding: String.Encoding.utf8)
    }
}
 */

extension SiteWebServiceRequest: WebServiceMockRequesting {
    var isSupportedRequest: Bool { return false }
    var timeWait: TimeInterval? { return 3 }
    
    var helperIdentifier: String? { return "template_html" }
    func createHelper() -> Any? {
        return "<html><body>%[BODY]%</body></html>"
    }
    
    func responseHandler(helper: Any?) throws -> String {
        if let template = helper as? String {
            return template.replacingOccurrences(of: "%[BODY]%", with: "<b>Hello world!</b>")
        } else {
            throw WebServiceResponseError.invalidData
        }
    }
}

