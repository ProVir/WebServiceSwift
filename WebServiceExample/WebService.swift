//
//  WebService.swift
//  WebServiceExample
//
//  Created by Короткий Виталий on 19.04.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation
import WebServiceSwift


///Default implementation and setup WebService
extension WebService {
    
    convenience init() {
        let endpoint = WebServiceHtmlEndpoint()
//        let endpoint = WebServiceSimpleEndpoint()
//        let endpoint = WebServiceAlamofireSimpleEndpoint()
        
        let mock = WebServiceMockEndpoint(rawDataFromStoreAlwaysNil: true)
        
        var storages: [WebServiceStorage] = []
        if let storage = WebServiceFileStorage() {
            storages.append(storage)
        }
        
        self.init(endpoints: [mock, endpoint], storages: storages)
    }
    
    static var `default`: WebService {
        return WebServiceStatic.default
    }
}

private struct WebServiceStatic {
    static let `default` = WebService()
}
