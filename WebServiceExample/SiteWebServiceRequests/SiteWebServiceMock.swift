//
//  SiteWebServiceMock.swift
//  WebServiceExample
//
//  Created by Короткий Виталий on 25.07.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation
import WebServiceSwift

struct SiteWebServiceMock {
    static let helperIdentifier = "template_html"
    static func createHelper() -> String {
        return "<html><body>%[BODY]%</body></html>"
    }
    
    static func responseHandler(helper: Any?) throws -> String {
        if let template = helper as? String {
            return template.replacingOccurrences(of: "%[BODY]%", with: "<b>Hello world!</b>")
        } else {
            throw WebServiceResponseError.invalidData
        }
    }
}

extension SiteWebServiceRequests.SiteSearch: WebServiceMockRequesting {
    var isSupportedRequestForMock: Bool { return false }
    var mockTimeDelay: TimeInterval? { return 3 }
    
    var mockHelperIdentifier: String? { return SiteWebServiceMock.helperIdentifier }
    func mockCreateHelper() -> Any? { return SiteWebServiceMock.createHelper() }
    
    func mockResponseHandler(helper: Any?) throws -> String {
        return try SiteWebServiceMock.responseHandler(helper: helper)
    }
}

extension SiteWebServiceRequests.SiteMail: WebServiceMockRequesting {
    var isSupportedRequestForMock: Bool { return false }
    var mockTimeDelay: TimeInterval? { return 4 }
    
    var mockHelperIdentifier: String? { return SiteWebServiceMock.helperIdentifier }
    func mockCreateHelper() -> Any? { return SiteWebServiceMock.createHelper() }
    
    func mockResponseHandler(helper: Any?) throws -> String {
        return try SiteWebServiceMock.responseHandler(helper: helper)
    }
}

extension SiteWebServiceRequests.SiteYouTube: WebServiceMockRequesting {
    var isSupportedRequestForMock: Bool { return false }
    var mockTimeDelay: TimeInterval? { return 1 }
    
    var mockHelperIdentifier: String? { return SiteWebServiceMock.helperIdentifier }
    func mockCreateHelper() -> Any? { return SiteWebServiceMock.createHelper() }
    
    func mockResponseHandler(helper: Any?) throws -> String {
        return try SiteWebServiceMock.responseHandler(helper: helper)
    }
}
