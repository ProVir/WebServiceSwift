//
//  WebService.swift
//  WebServiceExample
//
//  Created by Короткий Виталий on 24.08.17.
//  Copyright © 2017 ProVir. All rights reserved.
//

import Foundation
import WebServiceSwift
import Alamofire


extension WebService {
    
    convenience init(delegate:WebServiceDelegate? = nil) {
        let engine = WebServiceSitesEngine()
        
        var storages:[WebServiceStoraging] = []
        if let storage = WebServiceSimpleStore() {
            storages.append(storage)
        }
        
        self.init(engines: [engine], storages:storages)
        
        self.delegate = delegate
    }
    
    static var `default`: WebService {
        return WebServiceStatic.default
    }
}

private struct WebServiceStatic {
    static let `default` = WebService()
}



class WebServiceSitesEngine: WebServiceEngining {
    
    func isSupportedRequest(_ request: WebServiceRequesting, rawDataForRestoreFromStorage: Any?) -> Bool {
        return request is RequestMethod
    }

    func request(requestId: UInt64, request: WebServiceRequesting, saveRawDataToStorage: @escaping (Any) -> Void, completionResponse: @escaping (WebServiceResponse) -> Void) throws {
        
        guard let method = (request as? RequestMethod)?.method else {
            completionResponse(.error(WebServiceRequestError.notSupportRequest))
            return
        }
        
        Alamofire.request(method.url).responseData { response in
            switch response.result {
            case .success(let data):
                saveRawDataToStorage(data)
                
                let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1251)
                completionResponse(.data(html))
                
            case .failure(let error):
                completionResponse(.error(error))
            }
        }
    }
    
    
    func cancelRequest(requestId: UInt64) {
        
    }
    
    func processRawDataFromStorage(rawData: Any, request: WebServiceRequesting, completeResponse: @escaping (WebServiceResponse) -> Void) throws {
        
        if request is RequestMethod, let data = rawData as? Data {
            let html = String(data: data, encoding: .utf8)
            completeResponse(.data(html))
        }
        else {
            completeResponse(.error(WebServiceRequestError.notSupportDataHandler))
        }
    }
    
}


//Method urls
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


extension WebServiceMethod {
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
