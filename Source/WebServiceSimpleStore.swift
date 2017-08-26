//
//  WebServiceSimpleStore.swift
//  WebService 2.0.swift
//
//  Created by ViR (Короткий Виталий) on 29.07.17.
//  Copyright © 2017 ProVir. All rights reserved.
//

import Foundation


/// Conform to protocol if requests support store raw data.
public protocol WebServiceRequestRawStore: WebServiceRequesting {
    
    ///Unique identificator for read and write data if current request support store as raw data. May contain file type at the end.
    func identificatorForRawStore() -> String?
}

/// Conform to protocol if requests support store data.
public protocol WebServiceRequestCustomStore: WebServiceRequesting {
    
    ///Unique identificator for read and write data if current request support store as custom data. May contain file type at the end.
    func identificatorForCustomStore() -> String?
    
    /**
     Coding data from custom type to binary data.
 
     - Parameter value: Data with type from response.
     - Results: Binary data after coding if supported.
     */
    func writeDataToStore(value:Any) -> Data?
    
    /**
     Decoding data from binary data to custom type.
     
     - Parameter data: Binary data from disk.
     - Results: Custom type after decoding if supported.
     */
    func readDataFromStore(data:Data) throws -> Any?
}


/// Simple store on disk for WebService.
public class WebServiceSimpleStore: WebServiceStoraging {
    
    private enum FormatType: String {
        case raw
        case custom
    }
    
    
    private let fileWorkDispatchQueue:DispatchQueue
    private let filesDir:URL
    private let prefixNameFiles:String
    
    
    // MARK: Constructors
    
    /**
     Constructor with all settings store.
     
     - Parameters:
        - filesDir: Directory for store data.
        - prefixNameFiles: Prefix in name files for all data on disk in this store.
     */
    public init(filesDir:URL, prefixNameFiles:String) {
        fileWorkDispatchQueue = DispatchQueue(label: "ru.provir.WebServiceSimpleStore.fileWork",
                                              qos: .default)
        
        self.filesDir = filesDir
        self.prefixNameFiles = prefixNameFiles
    }
    
    /**
     Constructor with prefix name settings store. Files store in standart caches directory.
     
     - Parameter prefixNameFiles: Prefix in name files for all data on disk in this store.
     */
    public convenience init?(prefixNameFiles:String) {
        guard let filesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        self.init(filesDir: filesDir, prefixNameFiles: prefixNameFiles)
    }
    
    /**
     Constructor with default settings store. Files store in standart caches directory.
     
     Prefix name for all files: *webServiceSimpleStore*
     */
    public convenience init?() {
        self.init(prefixNameFiles: "webServiceSimpleStore")
    }
    
    
    // MARK: WebServiceStoraging
    public func isSupportedRequestForStorage(_ request: WebServiceRequesting) -> Bool {
        if let request = request as? WebServiceRequestRawStore,
            request.identificatorForRawStore() != nil {
            return true
        }
        else if let request = request as? WebServiceRequestCustomStore,
            request.identificatorForCustomStore() != nil {
            return true
        }
        else {
            return false
        }
    }
    
    public func readData(request: WebServiceRequesting, completionHandler: @escaping (Bool, WebServiceResponse) -> Void) throws {
        
        //Raw
        if let request = request as? WebServiceRequestRawStore,
            let identificator = request.identificatorForRawStore() {
            
            privateReadData(identificator: identificator, type: .raw, completionHandler: { (data, error) in
                if let error = error {
                    completionHandler(true, .error(error))
                }
                else {
                    completionHandler(true, .data(data))
                }
            })
            
            return
        }
        
        
        //Custom
        if let request = request as? WebServiceRequestCustomStore,
            let identificator = request.identificatorForCustomStore() {
            
            privateReadData(identificator: identificator, type: .custom, completionHandler: { binaryData, error in
                if let error = error {
                    completionHandler(false, .error(error))
                }
                else if let binaryData = binaryData {
                    do {
                        let data = try request.readDataFromStore(data: binaryData)
                        completionHandler(false, .data(data))
                    }
                    catch {
                        completionHandler(false, .error(error))
                    }
                }
                else {
                    completionHandler(false, .data(nil))
                }
            })
            
            return
        }
        
    }
    
    public func writeData(request: WebServiceRequesting, data: Any, isRaw: Bool) {
        
        //Raw
        if isRaw, let request = request as? WebServiceRequestRawStore,
            let identificator = request.identificatorForRawStore(),
            let binaryData = data as? Data {
            
            privateWriteData(identificator: identificator, type: .raw, data: binaryData)
            return
        }
        
        
        //Custom
        if !isRaw, let request = request as? WebServiceRequestCustomStore,
            let identificator = request.identificatorForCustomStore(),
            let binaryData = request.writeDataToStore(value: data) {
            
            privateWriteData(identificator: identificator, type: .custom, data: binaryData)
            return
        }
    }
    
    
    
    //MARK: Storage private
    private func privateReadData(identificator:String, type:FormatType, completionHandler: @escaping (Data?, Error?) -> Void) {
        let url = filesDir.appendingPathComponent("\(prefixNameFiles)_\(type.rawValue)_\(identificator)")
        
        
        fileWorkDispatchQueue.async {
            do {
                let data = try Data(contentsOf: url)
                
                DispatchQueue.main.async {
                    completionHandler(data, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completionHandler(nil, error)
                }
            }
        }
    }
    
    private func privateWriteData(identificator:String, type:FormatType, data:Data) {
        let url = filesDir.appendingPathComponent("\(prefixNameFiles)_\(type.rawValue)_\(identificator)")
        
        fileWorkDispatchQueue.async {
            try? data.write(to: url, options: .atomicWrite)
        }
    }
    
}
