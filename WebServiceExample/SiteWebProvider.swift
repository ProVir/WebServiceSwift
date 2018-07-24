//
//  SiteWebProvider.swift
//  WebServiceExample
//
//  Created by Короткий Виталий on 19.04.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation
import WebServiceSwift


//MARK: Provider
protocol SiteWebProviderDelegate: class {
    func webServiceResponse(request: WebServiceBaseRequesting, isStorageRequest: Bool, html: String)
    func webServiceResponse(request: WebServiceBaseRequesting, isStorageRequest: Bool, error: Error)
}

class SiteWebProvider: WebServiceProvider {
    private let webService: WebService
    
    required init(webService: WebService) {
        self.webService = webService
    }
    
    weak var delegate: SiteWebProviderDelegate?
    
    //MARK: Request use SiteWebProviderDelegate
    func requestHtmlDataFromSiteSearch(_ request: SiteWebServiceRequests.SiteSearch, includeResponseStorage: Bool) {
        if includeResponseStorage { internalReadStorageHtmlData(request, dataFromStorage: nil) }
        webService.performRequest(request, excludeDuplicate: true, responseDelegate: self)
    }
    
    func requestHtmlDataFromSiteMail(_ request: SiteWebServiceRequests.SiteMail, includeResponseStorage: Bool) {
        if includeResponseStorage { internalReadStorageHtmlData(request, dataFromStorage: nil) }
        webService.performRequest(request, key: request.site, excludeDuplicate: true, responseDelegate: self)
    }
    
    func requestHtmlDataFromSiteYouTube(includeResponseStorage: Bool) {
        let request = SiteWebServiceRequests.SiteYouTube()
        if includeResponseStorage { internalReadStorageHtmlData(request, dataFromStorage: nil) }
        webService.performRequest(request, responseDelegate: self)
    }
    
    //MARK: Request use closures
    func requestHtmlDataFromSiteSearch(_ request: SiteWebServiceRequests.SiteSearch,
                                       dataFromStorage: ((_ data:String) -> Void)? = nil,
                                       completionHandler: @escaping (_ response: WebServiceResponse<String>) -> Void) {
        if let dataFromStorage = dataFromStorage { internalReadStorageHtmlData(request, dataFromStorage: dataFromStorage) }
        webService.performRequest(request, completionHandler: completionHandler)
    }
    
    func requestHtmlDataFromSiteMail(_ request: SiteWebServiceRequests.SiteMail,
                                     dataFromStorage: ((_ data:String) -> Void)? = nil,
                                     completionHandler: @escaping (_ response: WebServiceResponse<String>) -> Void) {
        if let dataFromStorage = dataFromStorage { internalReadStorageHtmlData(request, dataFromStorage: dataFromStorage) }
        webService.performRequest(request, completionHandler: completionHandler)
    }
    
    func requestHtmlDataFromSiteYouTube(dataFromStorage: ((_ data:String) -> Void)? = nil,
                                        completionHandler: @escaping (_ response: WebServiceResponse<String>) -> Void) {
        let request = SiteWebServiceRequests.SiteYouTube()
        if let dataFromStorage = dataFromStorage { internalReadStorageHtmlData(request, dataFromStorage: dataFromStorage) }
        webService.performRequest(request, completionHandler: completionHandler)
    }
    
    func cancelAllRequests() {
        webService.cancelRequests(type: SiteWebServiceRequests.SiteSearch.self)
        webService.cancelRequests(keyType: SiteWebServiceRequests.SiteMail.Site.self)
        webService.cancelRequests(SiteWebServiceRequests.SiteYouTube())
    }
    
    //MARK: - Private
    private func internalReadStorageHtmlData(_ request: WebServiceBaseRequesting, dataFromStorage: ((_ data: String) -> Void)?) {
        if let dataFromStorage = dataFromStorage {
            webService.readStorageAnyData(request, dependencyNextRequest: .dependFull) { _, response in
                let response = response.convert(String.self)
                if case .data(let data) = response {
                    dataFromStorage(data)
                }
            }
        } else {
            webService.readStorage(request, dependencyNextRequest: .dependFull, responseOnlyData: true, responseDelegate: self)
        }
    }
    
}

extension SiteWebProvider: WebServiceDelegate {
    func webServiceResponse(request: WebServiceBaseRequesting, key: AnyHashable?, isStorageRequest: Bool, response: WebServiceAnyResponse) {
        
        let responseText: WebServiceResponse<String>
        if let request = request as? SiteWebServiceRequests.SiteSearch {
            responseText = response.convert(request: request)
        } else if let request = request as? SiteWebServiceRequests.SiteMail {
            responseText = response.convert(request: request)
        } else if let request = request as? SiteWebServiceRequests.SiteYouTube {
            responseText = response.convert(request: request)
        } else {
            return
        }
        
        switch responseText {
        case .data(let html):
            delegate?.webServiceResponse(request: request, isStorageRequest: isStorageRequest, html: html)
            
        case .error(let error):
            delegate?.webServiceResponse(request: request, isStorageRequest: isStorageRequest, error: error)
            
        case .canceledRequest, .duplicateRequest:
            break
        }
    }
}

