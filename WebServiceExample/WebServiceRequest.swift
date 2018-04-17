//
//  WebServiceRequest.swift
//  WebServiceExample
//
//  Created by Короткий Виталий on 24.08.17.
//  Copyright © 2017 ProVir. All rights reserved.
//

import Foundation
import WebServiceSwift


//MARK: Request
enum SiteWebServiceRequest: WebServiceRequesting, Equatable {
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



//MARK: Provider
protocol SiteWebServiceProviderDelegate: class {
    func webServiceResponse(request:SiteWebServiceRequest, isStorageRequest:Bool, html:String)
    func webServiceResponse(request:SiteWebServiceRequest, isStorageRequest:Bool, error:Error)
}

class SiteWebServiceProvider: WebServiceProvider<SiteWebServiceRequest> {
    weak var delegate: SiteWebServiceProviderDelegate?
    
    ///Request use SiteWebServiceProviderDelegate
    func requestHtmlData(_ request:SiteWebServiceRequest, includeResponseStorage: Bool) {
        self.request(request, includeResponseStorage: includeResponseStorage)
    }
    
    ///Request use closures
    func requestHtmlData(_ request:SiteWebServiceRequest, dataFromStorage:((_ data:String) -> Void)? = nil, completionHandler:((_ response:WebServiceProviderResponse<String>) -> Void)?) {
        self.request(request, dataFromStorage: dataFromStorage, completionResponse: completionHandler)
    }
    
    ///Override needed
    override func webServiceResponse(request: SiteWebServiceRequest, isStorageRequest: Bool, response: WebServiceResponse) {
        let response = WebServiceProviderResponse<String>(response: response)
        
        switch response {
        case .data(let html):
            delegate?.webServiceResponse(request: request, isStorageRequest: isStorageRequest, html: html)
            
        case .error(let error):
            delegate?.webServiceResponse(request: request, isStorageRequest: isStorageRequest, error: error)
            
        case .canceledRequest, .duplicateRequest:
            break
        }
    }
}


//MARK: Urls
extension SiteSearchType {
    func url(domain:String) -> URL {
        switch self {
        case .google: return URL(string: "http://google.\(domain)")!
        case .yandex: return URL(string: "http://yandex.\(domain)")!
        }
    }
}

extension SiteMailType {
    func url() -> URL {
        switch self {
        case .google: return URL(string: "http://mail.google.com")!
        case .yandex: return URL(string: "http://mail.yandex.ru")!
        case .mail: return URL(string: "http://e.mail.ru")!
        }
    }
}


extension SiteWebServiceRequest {
    var url:URL {
        switch self {
        case .siteSearch(let type, domain: let domain):
            return type.url(domain: domain)
            
        case .siteMail(let type):
            return type.url()
            
        case .siteYouTube:
            return URL(string: "http://youtube.ru")!
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


