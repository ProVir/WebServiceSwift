//
//  SiteWebServiceStoring.swift
//  WebServiceExample
//
//  Created by Короткий Виталий on 25.07.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation
import WebServiceSwift

extension SiteWebServiceRequests.SiteSearch: WebServiceRequestRawGeneralStoring {
//    var dataClassificationForStorage: AnyHashable { return WebServiceDataClass.temporary }
    var identificatorForStorage: String? { return site.rawValue + ".\(domain)" }
}

extension SiteWebServiceRequests.SiteMail: WebServiceRequestValueGeneralStoring {
    var identificatorForStorage: String? { return site.rawValue }
    
    func writeDataToStorage(value: String) -> Data? {
        return value.data(using: String.Encoding.utf8)
    }
    
    func readDataFromStorage(data: Data) throws -> String? {
        return String(data: data, encoding: String.Encoding.utf8)
    }
}

extension SiteWebServiceRequests.SiteYouTube: WebServiceRequestRawFileStoring {
    var identificatorForFileStorage: String? { return "siteYouTube" }
}

//extension SiteWebServiceRequests.SiteYouTube: WebServiceRequestRawDataBaseStoring {
//    var identificatorForDataBaseStorage: String? { return "siteYouTube" }
//}

