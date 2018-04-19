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
    
    let siteWebProvider = SiteWebProvider(webService: WebService())
    

    override func viewDidLoad() {
        super.viewDidLoad()
        

        siteWebProvider.delegate = self
    }

    
    @IBAction func actionChangeRaw() {
        if rawSwitch.isOn {
            rawTextView.isHidden = false
            webView.isHidden = true
        }
        else {
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
                                        self.requestMethod(.siteSearch(.google, domain: "com"))
        }))
        
        alert.addAction(UIAlertAction(title: "Google.ru",
                                      style: .default,
                                      handler: { _ in
                                        self.requestMethod(.siteSearch(.google, domain: "ru"))
        }))
        
        alert.addAction(UIAlertAction(title: "Yandex.ru",
                                      style: .default,
                                      handler: { _ in
                                        self.requestMethod(.siteSearch(.yandex, domain: "ru"))
        }))
        
        alert.addAction(UIAlertAction(title: "GMail",
                                      style: .default,
                                      handler: { _ in
                                        self.requestMethod(.siteMail(.google))
        }))
        
        alert.addAction(UIAlertAction(title: "Mail.ru",
                                      style: .default,
                                      handler: { _ in
                                        self.requestMethod(.siteMail(.mail))
        }))
        
        alert.addAction(UIAlertAction(title: "YouTube",
                                      style: .default,
                                      handler: { _ in
                                        self.requestMethod(.siteYouTube)
        }))
        
        
        present(alert, animated: true, completion: nil)
    }
    
    
    func requestMethod(_ site:SiteWebServiceRequest) {
        /*
            1. Use closure recommendation variant
        */
//        siteWebProvider.requestHtmlData(site, dataFromStorage: { [weak self] html in
//            self?.rawTextView.text = html
//            self?.webView.loadHTMLString(html, baseURL: site.url)
//
//        }) { [weak self] response in
//            switch response {
//            case .data(let html):
//                self?.rawTextView.text = html
//                self?.webView.loadHTMLString(html, baseURL: site.url)
//
//            case .error(let error):
//                let text = (error as NSError).localizedDescription
//
//                let alert = UIAlertController(title: "Error", message: text, preferredStyle: .alert)
//                alert.addAction(UIAlertAction(title: "OK",
//                                              style: .default,
//                                              handler: nil))
//
//                self?.present(alert, animated: true, completion: nil)
//
//            case .canceledRequest, .duplicateRequest:
//                break
//            }
//        }
        
        /*
            2. Use closure without SiteWebServiceProvider variant - as siteWebProvider: WebServiceProvider<SiteWebServiceRequest>
        */
//        siteWebProvider.request(site, dataFromStorage: { [weak self] (html:String) in
//            self?.rawTextView.text = html
//            self?.webView.loadHTMLString(html, baseURL: site.url)
//
//        }) { [weak self] (response: WebServiceTypeResponse<String>) in
//            switch response {
//            case .data(let html):
//                self?.rawTextView.text = html
//                self?.webView.loadHTMLString(html, baseURL: site.url)
//
//            case .error(let error):
//                let text = (error as NSError).localizedDescription
//
//                let alert = UIAlertController(title: "Error", message: text, preferredStyle: .alert)
//                alert.addAction(UIAlertAction(title: "OK",
//                                              style: .default,
//                                              handler: nil))
//
//                self?.present(alert, animated: true, completion: nil)
//
//            case .canceledRequest, .duplicateRequest:
//                break
//            }
//        }
        
        
        
        /*
            3. Use delegate
        */
        siteWebProvider.requestHtmlData(site, includeResponseStorage: true)
    }
    

    
}

extension ViewController: SiteWebProviderDelegate {
    func webServiceResponse(request: SiteWebServiceRequest, isStorageRequest: Bool, html: String) {
        let baseUrl = request.baseUrl
        
        rawTextView.text = html
        webView.loadHTMLString(html, baseURL: baseUrl)
    }
    
    func webServiceResponse(request: SiteWebServiceRequest, isStorageRequest: Bool, error: Error) {
        let text = (error as NSError).localizedDescription
        
        let alert = UIAlertController(title: "Error", message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK",
                                      style: .default,
                                      handler: nil))
        
        present(alert, animated: true, completion: nil)
    }
}
