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
    struct Helper: WebServiceMockHelper {
        let template: String
    }

    static let helperIdentifier = "template_html"
    static func createHelper() -> Helper {
        return .init(template: "<html><body>%[BODY]%</body></html>")
    }
    
    static func responseHandler(helper: WebServiceMockHelper?) throws -> String {
        if let template = (helper as? Helper)?.template {
            return template.replacingOccurrences(of: "%[BODY]%", with: "<b>Hello world!</b>")
        } else {
            throw WebServiceRequestError.gatewayInternal
        }
    }
}

extension SiteWebServiceRequests.SiteSearch: WebServiceMockRequesting {
    var isSupportedRequestForMock: Bool { return false }
    var mockTimeDelay: TimeInterval? { return 3 }
    
    var mockHelperIdentifier: String? { return SiteWebServiceMock.helperIdentifier }
    func mockCreateHelper() -> WebServiceMockHelper? { return SiteWebServiceMock.createHelper() }
    
    func mockResponseHandler(helper: WebServiceMockHelper?) throws -> String {
        return try SiteWebServiceMock.responseHandler(helper: helper)
    }
}

extension SiteWebServiceRequests.SiteMail: WebServiceMockRequesting {
    var isSupportedRequestForMock: Bool { return false }
    var mockTimeDelay: TimeInterval? { return 4 }
    
    var mockHelperIdentifier: String? { return SiteWebServiceMock.helperIdentifier }
    func mockCreateHelper() -> WebServiceMockHelper? { return SiteWebServiceMock.createHelper() }
    
    func mockResponseHandler(helper: WebServiceMockHelper?) throws -> String {
        return try SiteWebServiceMock.responseHandler(helper: helper)
    }
}

extension SiteWebServiceRequests.SiteYouTube: WebServiceMockRequesting {
    var isSupportedRequestForMock: Bool { return false }
    var mockTimeDelay: TimeInterval? { return 1 }
    
    var mockHelperIdentifier: String? { return SiteWebServiceMock.helperIdentifier }
    func mockCreateHelper() -> WebServiceMockHelper? { return SiteWebServiceMock.createHelper() }
    
    func mockResponseHandler(helper: WebServiceMockHelper?) throws -> String {
        return try SiteWebServiceMock.responseHandler(helper: helper)
    }
}
