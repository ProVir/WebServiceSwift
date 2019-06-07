//
//  WebService.swift
//  WebServiceExample
//
//  Created by Короткий Виталий on 19.04.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation
import WebServiceSwift

enum WebServiceDataClass: Hashable {
    case temporary
}

///Default implementation and setup WebService
extension WebService {
    
    static func createDefault() -> WebService {
        let gateway = WebServiceHtmlV2GatewayHandler.makeGateway()
//        let gateway = WebServiceSimpleGateway()
//        let gateway = AlamofireSimpleGateway()

        let mock = WebServiceMockGateway(rawDataFromStoreAlwaysNil: true)
        
        var storages: [WebServiceStorage] = []
        storages.append(WebServiceMemoryStorage(supportDataClassification: [WebServiceDataClass.temporary]))
        
        if let storage = WebServiceDataBaseStorage() {
            storages.append(storage)
        }
        
        if let storage = WebServiceFileStorage() {
            storages.append(storage)
        }
        
        /*
        let template = "<html><body>%[BODY]%</body></html>"
        let mockRequest = WebServiceMockRequestGateway(timeDelay: 3) { (request: SiteWebServiceRequests.SiteSearch) -> String in
            return template.replacingOccurrences(of: "%[BODY]%", with: "<b>Hello world from MockRequestGateway!</b>")
        }
        */
        
        return .init(gateways: [/*mockRequest, */mock, gateway], storages: storages)
    }
    
    static var `default`: WebService {
        return WebServiceStatic.default
    }
}

private struct WebServiceStatic {
    static let `default` = WebService.createDefault()
}
