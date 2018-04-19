//
//  SiteWebProvider.swift
//  WebServiceExample
//
//  Created by Короткий Виталий on 19.04.2018.
//  Copyright © 2018 ProVir. All rights reserved.
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
protocol SiteWebProviderDelegate: class {
    func webServiceResponse(request:SiteWebServiceRequest, isStorageRequest:Bool, html:String)
    func webServiceResponse(request:SiteWebServiceRequest, isStorageRequest:Bool, error:Error)
}

class SiteWebProvider: WebServiceProvider<SiteWebServiceRequest> {
    weak var delegate: SiteWebProviderDelegate?
    
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



//MARK: BaseURL information

///Presentation layer and other don't need dependency from network layer implementation: `baseUrl` don't use `url`, because `url` use only implementation for Engine (protocol `WebServiceHtmlRequesting`). But `url` can use `baseUrl` as part original request.'
extension SiteWebServiceRequest {
    var baseUrl:URL {
        switch self {
        case .siteSearch(let type, domain: let domain):
            return type.baseUrl(domain: domain)
            
        case .siteMail(let type):
            return type.baseUrl()
            
        case .siteYouTube:
            return URL(string: "https://www.youtube.com")!
        }
    }
}

extension SiteSearchType {
    func baseUrl(domain:String) -> URL {
        switch self {
        case .google: return URL(string: "https://google.\(domain)")!
        case .yandex: return URL(string: "https://yandex.\(domain)")!
        }
    }
}

extension SiteMailType {
    func baseUrl() -> URL {
        switch self {
        case .google: return URL(string: "https://mail.google.com")!
        case .yandex: return URL(string: "https://mail.yandex.ru")!
        case .mail: return URL(string: "https://e.mail.ru")!
        }
    }
}
