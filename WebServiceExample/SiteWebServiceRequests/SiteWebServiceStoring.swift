//
//  SiteWebServiceStoring.swift
//  WebServiceExample
//
//  Created by Короткий Виталий on 25.07.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation
import WebServiceSwift

extension SiteWebServiceRequests.SiteSearch: WebServiceRequestEasyStoring {
//    var dataClassificationForStorage: AnyHashable { return WebServiceDataClass.temporary }
    var identificatorForStorage: String? { return site.rawValue + ".\(domain)" }
}

extension SiteWebServiceRequests.SiteMail: WebServiceRequestBinaryValueStoring {
    var identificatorForStorage: String? { return site.rawValue }

    func encodeToBinaryForStorage(value: String) -> Data? {
        return value.data(using: String.Encoding.utf8)
    }

    func decodeToValueFromStorage(binary: Data) throws -> String? {
        return String(data: binary, encoding: String.Encoding.utf8)
    }
}

extension SiteWebServiceRequests.SiteYouTube: WebServiceRequestEasyStoring {
    var identificatorForStorage: String? { return "siteYouTube" }
}

