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
        
        var storages:[WebServiceStoraging] = []
        if let storage = WebServiceSimpleFileStorage() {
            storages.append(storage)
        }
        
        self.init(engines: [engine], storages:storages)
    }
    
    static var `default`: WebService {
        return WebServiceStatic.default
    }
}

private struct WebServiceStatic {
    static let `default` = WebService()
}
