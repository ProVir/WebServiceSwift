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
class SiteWebProvider: WebServiceProvider {
    private let webService: WebService
    
    required init(webService: WebService) {
        self.webService = webService
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
    private func internalReadStorageHtmlData(_ request: WebServiceBaseRequesting, dataFromStorage: @escaping ((_ data: String) -> Void)) {
        webService.readStorageAnyData(request, dependencyNextRequest: .dependFull) { _, response in
            let response = response.convert(String.self)
            if case .data(let data) = response {
                dataFromStorage(data)
            }
        }
    }
}

