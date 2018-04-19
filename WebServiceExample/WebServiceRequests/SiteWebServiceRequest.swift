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
    var url:URL {
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
extension SiteWebServiceRequest: WebServiceRequestRawStore {
    func identificatorForRawStore() -> String? {
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


