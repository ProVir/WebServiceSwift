//
//  WebServiceSimpleFileStorage.swift
//  WebServiceSwift 2.2.0
//
//  Created by ViR (Короткий Виталий) on 29.07.17.
//  Updated to 2.2.0 by ViR (Короткий Виталий) on 16.05.2018.
//  Copyright © 2017 ProVir. All rights reserved.
//

import Foundation


/// Conform to protocol if requests support store raw data.
public protocol WebServiceRequestRawStorage: WebServiceBaseRequesting {
    
    ///Unique identificator for read and write data if current request support storage as raw data. May contain file type at the end.
    var identificatorForRawStorage: String? { get }
}

/// Conform to protocol if requests support store data.
public protocol WebServiceRequestValueStorage: WebServiceBaseRequesting {
    
    ///Unique identificator for read and write data if current request support storage as custom data. May contain file type at the end.
    var identificatorForValueStorage: String? { get }
    
    /**
     Coding data from custom type to binary data.
 
     - Parameter value: Data with type from response.
     - Results: Binary data after coding if supported.
     */
    func writeDataToStorage(value: Any) -> Data?
    
    /**
     Decoding data from binary data to custom type.
     
     - Parameter data: Binary data from disk.
     - Results: Custom type after decoding if supported.
     */
    func readDataFromStorage(data: Data) throws -> Any?
}


/// Simple store on disk for WebService.
public class WebServiceSimpleFileStorage: WebServiceStoraging {
    
    private enum FormatType: String {
        case raw
        case value
    }
    
    private let fileWorkDispatchQueue: DispatchQueue
    private let filesDir: URL
    private let prefixNameFiles: String
    
    // MARK: Constructors
    
    /**
     Constructor with all settings store.
     
     - Parameters:
        - filesDir: Directory for store data.
        - prefixNameFiles: Prefix in name files for all data on disk in this store.
     */
    public init(filesDir: URL, prefixNameFiles: String) {
        fileWorkDispatchQueue = DispatchQueue(label: "ru.provir.WebServiceSimpleFileStorage.fileWork",
                                              qos: .default)
        
        self.filesDir = filesDir
        self.prefixNameFiles = prefixNameFiles
    }
    
    /**
     Constructor with prefix name settings store. Files store in standart caches directory.
     
     - Parameter prefixNameFiles: Prefix in name files for all data on disk in this store.
     */
    public convenience init?(prefixNameFiles: String) {
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
        self.init(prefixNameFiles: "webServiceSimpleFileStorage")
    }
    
    
    // MARK: WebServiceStoraging
    public func isSupportedRequestForStorage(_ request: WebServiceBaseRequesting) -> Bool {
        if let request = request as? WebServiceRequestRawStorage,
            request.identificatorForRawStorage != nil {
            return true
            
        } else if let request = request as? WebServiceRequestValueStorage,
            request.identificatorForValueStorage != nil {
            return true
            
        } else {
            return false
        }
    }
    
    public func readData(request: WebServiceBaseRequesting, completionHandler: @escaping (Bool, WebServiceAnyResponse) -> Void) throws {
        //Raw
        if let request = request as? WebServiceRequestRawStorage,
            let identificator = request.identificatorForRawStorage {
            
            privateReadData(identificator: identificator, type: .raw, completionHandler: { (data, error) in
                if let error = error {
                    completionHandler(true, .error(error))
                } else {
                    completionHandler(true, .data(data))
                }
            })
        }
        
        //Custom
        else if let request = request as? WebServiceRequestValueStorage,
            let identificator = request.identificatorForValueStorage {
            
            privateReadData(identificator: identificator, type: .value, completionHandler: { binaryData, error in
                if let error = error {
                    completionHandler(false, .error(error))
                    
                } else if let binaryData = binaryData {
                    do {
                        let data = try request.readDataFromStorage(data: binaryData)
                        completionHandler(false, .data(data))
                    } catch {
                        completionHandler(false, .error(error))
                    }
                    
                } else {
                    completionHandler(false, .data(nil))
                }
            })
        }
    }
    
    public func writeData(request: WebServiceBaseRequesting, data: Any, isRaw: Bool) {
        //Raw
        if isRaw, let request = request as? WebServiceRequestRawStorage,
            let identificator = request.identificatorForRawStorage,
            let binaryData = data as? Data {
            
            privateWriteData(identificator: identificator, type: .raw, data: binaryData)
        }
        
        //Custom
        else if !isRaw, let request = request as? WebServiceRequestValueStorage,
            let identificator = request.identificatorForValueStorage,
            let binaryData = request.writeDataToStorage(value: data) {
            
            privateWriteData(identificator: identificator, type: .value, data: binaryData)
        }
    }

    //MARK: Storage private
    private func privateReadData(identificator: String, type: FormatType, completionHandler: @escaping (Data?, Error?) -> Void) {
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
    
    private func privateWriteData(identificator: String, type: FormatType, data: Data) {
        let url = filesDir.appendingPathComponent("\(prefixNameFiles)_\(type.rawValue)_\(identificator)")
        
        fileWorkDispatchQueue.async {
            try? data.write(to: url, options: .atomicWrite)
        }
    }
}
