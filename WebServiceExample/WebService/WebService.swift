//
//  WebService.swift
//  WebServiceExample
//
//  Created by Короткий Виталий on 19.04.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation
import WebServiceSwift

enum WebServiceDataClass: String {
    case temporary
}

///Default implementation and setup WebService
extension WebService {
    
    static func createDefault() -> WebService {
        let endpoint = WebServiceHtmlV2Endpoint()
//        let endpoint = WebServiceSimpleEndpoint()
//        let endpoint = WebServiceAlamofireSimpleEndpoint()
        
        let mock = WebServiceMockEndpoint(rawDataFromStoreAlwaysNil: true)
        
        var storages: [WebServiceStorage] = []
        if let storage = WebServiceDataBaseStorage() {
            storages.append(storage)
        }
        if let storage = WebServiceFileStorage() {
            storages.append(storage)
        }
        storages.append(WebServiceMemoryStorage(supportDataClassification: [WebServiceDataClass.temporary]))
        
        
        /*
        let template = "<html><body>%[BODY]%</body></html>"
        let mockRequest = WebServiceMockRequestEndpoint.init(timeWait: 3) { (request: SiteWebServiceRequests.SiteSearch) -> String in
            return template.replacingOccurrences(of: "%[BODY]%", with: "<b>Hello world from MockRequestEndpoint!</b>")
        }
        */
        
        return .init(endpoints: [/*mockRequest, */mock, endpoint], storages: storages)
    }
    
    static var `default`: WebService {
        return WebServiceStatic.default
    }
}

private struct WebServiceStatic {
    static let `default` = WebService.createDefault()
}
