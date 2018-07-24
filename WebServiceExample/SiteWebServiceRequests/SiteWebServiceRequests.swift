//
//  SiteWebServiceRequests.swift
//  WebServiceExample
//
//  Created by Короткий Виталий on 24.07.18.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation
import WebServiceSwift
import Alamofire

//MARK: Request
struct SiteWebServiceRequests: WebServiceGroupRequests {
    static let requestTypes: [WebServiceBaseRequesting.Type]
        = [SiteSearch.self, SiteMail.self, SiteYouTube.self]
    
    struct SiteSearch: WebServiceRequesting, Hashable {
        let site: Site
        let domain: String
        typealias ResultType = String
        
        enum Site: String {
            case google
            case yandex
        }
    }
    
    struct SiteMail: WebServiceRequesting, Hashable {
        let site: Site
        typealias ResultType = String
        
        enum Site: String {
            case google
            case mail
            case yandex
        }
    }
    
    struct SiteYouTube: WebServiceEmptyRequesting, Hashable {
        typealias ResultType = String
    }
}


//MARK: URL for requests
extension SiteWebServiceRequests.SiteSearch {
    var urlSite: URL {
        switch site {
        case .google: return URL(string: "https://google.\(domain)")!
        case .yandex: return URL(string: "https://yandex.\(domain)")!
        }
    }
}

extension SiteWebServiceRequests.SiteMail {
    var urlSite: URL {
        switch site {
        case .google: return URL(string: "https://mail.google.com")!
        case .yandex: return URL(string: "https://mail.yandex.ru")!
        case .mail: return URL(string: "https://e.mail.ru")!
        }
    }
}

extension SiteWebServiceRequests.SiteYouTube {
    var urlSite: URL {
        return URL(string: "https://www.youtube.com/?gl=RU&hl=ru")!
    }
}


