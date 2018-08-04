//
//  ViewController.swift
//  WebServiceExample
//
//  Created by Короткий Виталий on 24.08.17.
//  Copyright © 2017 ProVir. All rights reserved.
//

import UIKit
import WebServiceSwift

class ViewController: UIViewController {
    
    @IBOutlet weak var rawTextView: UITextView!
    @IBOutlet weak var webView: UIWebView!
    @IBOutlet weak var rawSwitch: UISwitch!
    
    let siteWebProvider: SiteWebProvider = WebService.createDefault().createProvider()
    let siteYouTubeProvider: WebServiceRequestProvider<SiteWebServiceRequests.SiteYouTube> = WebService.default.createProvider()
    let siteWebGroupProvider = WebServiceGroupProvider<SiteWebServiceRequests>(webService: WebService.default.clone())
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let rawLabel = UILabel(frame: .zero)
        rawLabel.text = "Raw mode: "
        rawLabel.sizeToFit()
        let rawItem = UIBarButtonItem(customView: rawLabel)
        navigationItem.rightBarButtonItems?.append(rawItem)
        
        
        siteWebProvider.delegate = self
        siteYouTubeProvider.excludeDuplicateDefault = true
    }

    @IBAction func actionChangeRaw() {
        if rawSwitch.isOn {
            rawTextView.isHidden = false
            webView.isHidden = true
        } else {
            rawTextView.isHidden = true
            webView.isHidden = false
        }
    }

    @IBAction func actionSelect(_ sender: Any) {
        let alert = UIAlertController(title: "Site select", message: "Select site to go, please:", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        alert.addAction(UIAlertAction(title: "Google.com",
                                      style: .default,
                                      handler: { _ in
                                        self.requestSiteSearch(.init(site: .google, domain: "com"))
        }))
        
        alert.addAction(UIAlertAction(title: "Google.ru",
                                      style: .default,
                                      handler: { _ in
                                        self.requestSiteSearch(.init(site: .google, domain: "ru"))
        }))
        
        alert.addAction(UIAlertAction(title: "Yandex.ru",
                                      style: .default,
                                      handler: { _ in
                                        self.requestSiteSearch(.init(site: .yandex, domain: "ru"))
        }))
        
        alert.addAction(UIAlertAction(title: "GMail",
                                      style: .default,
                                      handler: { _ in
                                        self.requestSiteMail(.init(site: .google))
        }))
        
        alert.addAction(UIAlertAction(title: "Mail.ru",
                                      style: .default,
                                      handler: { _ in
                                        self.requestSiteMail(.init(site: .mail))
        }))
        
        alert.addAction(UIAlertAction(title: "YouTube",
                                      style: .default,
                                      handler: { _ in
                                        self.requestSiteYouTube()
        }))
        
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func actionDeleteAll(_ sender: UIBarButtonItem) {
        WebService.default.deleteAllInStorages()
    }
    
    
    //MARK: Requests
    func requestSiteSearch(_ request: SiteWebServiceRequests.SiteSearch) {
        siteWebProvider.cancelAllRequests()
        siteYouTubeProvider.cancelRequests()
        
        siteWebProvider.requestHtmlDataFromSiteSearch(request, dataFromStorage: { [weak self] html in
            self?.rawTextView.text = html
            self?.webView.loadHTMLString(html, baseURL: request.urlSite)
            
        }) { [weak self] response in
            switch response {
            case .data(let html):
                self?.webServiceResponse(request: request, isStorageRequest: false, html: html)
                
            case .error(let error):
                self?.webServiceResponse(isStorageRequest: false, error: error)
                
            case .canceledRequest:
                break
            }
        }
    }
    
    func requestSiteMail(_ request: SiteWebServiceRequests.SiteMail) {
        siteYouTubeProvider.cancelRequests()
        
        siteWebProvider.requestHtmlDataFromSiteMail(request, includeResponseStorage: true)
    }
    
    func requestSiteYouTube() {
        siteWebProvider.cancelAllRequests()
        
        siteYouTubeProvider.readStorage(dependencyNextRequest: .dependFull) { [weak self] (timeStamp, response) in
            if case .data(let html) = response {
                if let timeStamp = timeStamp { print("Data from storage timeStamp = \(timeStamp)") }
                self?.webServiceResponse(request: SiteWebServiceRequests.SiteYouTube(), isStorageRequest: true, html: html)
            }
        }
        
        siteYouTubeProvider.performRequest { [weak self] response in
            switch response {
            case .data(let html):
                self?.webServiceResponse(request: SiteWebServiceRequests.SiteYouTube(), isStorageRequest: false, html: html)
                
            case .error(let error):
                self?.webServiceResponse(isStorageRequest: false, error: error)
                
            case .canceledRequest:
                break
            }
        }
    }
}

//MARK: Responses
extension ViewController: SiteWebProviderDelegate {
    func webServiceResponse(request: WebServiceBaseRequesting, isStorageRequest: Bool, html: String) {
        let baseUrl: URL
        if let request = request as? SiteWebServiceRequests.SiteSearch {
            baseUrl = request.urlSite
        } else if let request = request as? SiteWebServiceRequests.SiteMail {
            baseUrl = request.urlSite
        } else if let request = request as? SiteWebServiceRequests.SiteYouTube {
            baseUrl = request.urlSite
        } else {
            return
        }
        
        rawTextView.text = html
        webView.loadHTMLString(html, baseURL: baseUrl)
    }
    
    func webServiceResponse(request: WebServiceBaseRequesting, isStorageRequest: Bool, error: Error) {
        webServiceResponse(isStorageRequest: isStorageRequest, error: error)
    }
    
    func webServiceResponse(isStorageRequest: Bool, error: Error) {
        if isStorageRequest {
            print("Error read from storage: \(error)")
            return
        }
        
        let text = (error as NSError).localizedDescription
        
        let alert = UIAlertController(title: "Error", message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK",
                                      style: .default,
                                      handler: nil))
        
        present(alert, animated: true, completion: nil)
    }
}
