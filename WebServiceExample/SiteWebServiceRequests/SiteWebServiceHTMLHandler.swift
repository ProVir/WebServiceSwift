//
//  SiteWebServiceHTMLHandler.swift
//  WebServiceExample
//
//  Created by Короткий Виталий on 24.07.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation


/// As HTML Request - Support WebServiceHTMLEndpoint with concrete URL query.
extension SiteWebServiceRequests.SiteSearch: WebServiceHtmlRequesting {
    var url: URL { return urlSite }
}

extension SiteWebServiceRequests.SiteMail: WebServiceHtmlRequesting {
    var url: URL { return urlSite }
}

extension SiteWebServiceRequests.SiteYouTube: WebServiceHtmlRequesting {
    var url: URL { return urlSite }
}
