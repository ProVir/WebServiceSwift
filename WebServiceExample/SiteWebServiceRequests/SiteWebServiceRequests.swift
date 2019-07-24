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

enum ParseResponseError: Error {
    case unknownTextEncoding
}

//MARK: Request
enum SiteWebServiceRequests {
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

    struct ExampleCodingResponse: WebServiceEmptyRequesting {
        typealias ResultType = Response

        struct Response: Codable {
            let key: String
            let value: Int
        }
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


