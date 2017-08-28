//
//  WebServiceRequest.swift
//  WebServiceExample
//
//  Created by Короткий Виталий on 24.08.17.
//  Copyright © 2017 ProVir. All rights reserved.
//

import Foundation
import WebService


struct RequestMethod: WebServiceRequesting {
    let method:WebServiceMethod
    
    var requestKey:AnyHashable? {
        switch method {
        case .siteSearch(let type, domain: let domain):
            return type.rawValue + ".\(domain)"
            
        case .siteMail(let type):
            return type.rawValue
            
        case .siteYouTube:
            return "siteYouTube"
        }
    }
    
    init(_ method:WebServiceMethod) {
        self.method = method
    }
}

enum WebServiceMethod {
    case siteSearch(SiteSearchType, domain:String)
    case siteMail(SiteMailType)
    case siteYouTube
}

enum SiteSearchType: String {
    case google
    case yandex
}

enum SiteMailType: String {
    case google
    case mail
    case yandex
}


//Store
extension RequestMethod: WebServiceRequestRawStore {
    func identificatorForRawStore() -> String? {
        return requestKey as? String
    }
}
