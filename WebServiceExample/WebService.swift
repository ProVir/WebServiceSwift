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
        let engine = WebServiceHtmlEngine()
//        let engine = WebServiceSimpleEngine()
//        let engine = WebServiceAlamofireSimpleEngine()
        
        let mock = WebServiceMockEngine(rawDataFromStoreAlwaysNil: true)
        
        var storages: [WebServiceStoraging] = []
        if let storage = WebServiceFileStorage() {
            storages.append(storage)
        }
        
        self.init(engines: [mock, engine], storages: storages)
    }
    
    static var `default`: WebService {
        return WebServiceStatic.default
    }
}

private struct WebServiceStatic {
    static let `default` = WebService()
}
