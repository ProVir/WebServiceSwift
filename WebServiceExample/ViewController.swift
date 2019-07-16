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
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let rawLabel = UILabel(frame: .zero)
        rawLabel.text = "Raw mode: "
        rawLabel.sizeToFit()
        let rawItem = UIBarButtonItem(customView: rawLabel)
        navigationItem.rightBarButtonItems?.append(rawItem)

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
        
        siteWebProvider.requestHtmlDataFromSiteSearch(
            request,
            dataFromStorage: { [weak self] html in
                self?.showContent(urlSite: request.urlSite, html: html)
            },
            completionHandler: { [weak self] response in
                self?.webServiceResponse(urlSite: request.urlSite, fromStorage: false, response: response)
            }
        )
    }
    
    func requestSiteMail(_ request: SiteWebServiceRequests.SiteMail) {
        siteYouTubeProvider.cancelRequests()

        siteWebProvider.requestHtmlDataFromSiteMail(
            request,
            dataFromStorage: { [weak self] html in
                self?.showContent(urlSite: request.urlSite, html: html)
            },
            completionHandler: { [weak self] response in
                self?.webServiceResponse(urlSite: request.urlSite, fromStorage: false, response: response)
            }
        )
    }
    
    func requestSiteYouTube() {
        let urlSite = SiteWebServiceRequests.SiteYouTube().urlSite
        siteWebProvider.cancelAllRequests()

        siteYouTubeProvider.readStorage(dependencyNextRequest: .dependFull) { [weak self] (timeStamp, response) in
            if let timeStamp = timeStamp { print("Data from storage timeStamp = \(timeStamp)") }
            self?.webServiceResponse(urlSite: urlSite, fromStorage: true, response: response)
        }

        siteYouTubeProvider.performRequest { [weak self] response in
            self?.webServiceResponse(urlSite: urlSite, fromStorage: false, response: response)
        }
    }
}

// MARK: Responses
extension ViewController {
    private func showContent(urlSite: URL, html: String) {
        rawTextView.text = html
        webView.loadHTMLString(html, baseURL: urlSite)
    }

    private func showError(_ error: Error) {
        let text = (error as NSError).localizedDescription

        let alert = UIAlertController(title: "Error", message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK",
                                      style: .default,
                                      handler: nil))

        present(alert, animated: true, completion: nil)
    }

    private func webServiceResponse(urlSite: URL, fromStorage: Bool, response: WebServiceResponse<String>) {
        switch response {
        case .data(let html):
            showContent(urlSite: urlSite, html: html)

        case .error(let error):
            if fromStorage {
                print("Error read from storage: \(error)")
            } else {
                showError(error)
            }

        case .canceledRequest: break
        }
    }
}
