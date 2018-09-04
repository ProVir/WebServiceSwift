//
//  WebServiceFileStorage.swift
//  WebServiceSwift 3.0.0
//
//  Created by Короткий Виталий (ViR) on 29.07.17.
//  Updated to 3.0.0 by Короткий Виталий (ViR) on 04.09.2018.
//  Copyright © 2017 - 2018 ProVir. All rights reserved.
//

import Foundation


/// Base protocol for requests support WebServiceFileStorage.
public protocol WebServiceRequestBaseFileStoring: WebServiceRequestBaseStoring {
    
    /// Unique identificator for read and write data if current request support storage.
    var identificatorForFileStorage: String? { get }
    
    /// If `true` - use save data for disk as internal type with user data, isRaw flag and timeStamp. Else save only user data binary for disk. Default: true.
    var useWrapperWithMetaDataForFileStorage: Bool { get }
}

public extension WebServiceRequestBaseFileStoring {
    var useWrapperWithMetaDataForFileStorage: Bool { return true }
}

/// Conform to protocol if requests support WebServiceFileStorage and store raw data as file.
public protocol WebServiceRequestRawFileStoring: WebServiceRequestBaseFileStoring { }

/// Conform to protocol if requests support WebServiceFileStorage and store value data as file.
public protocol WebServiceRequestAnyValueFileStoring: WebServiceRequestBaseFileStoring {
    
    /**
     Coding data from custom type to binary data.
 
     - Parameter value: Data with type from response.
     - Results: Binary data after coding if supported.
     */
    func writeAnyDataToFileStorage(value: Any) -> Data?
    
    /**
     Decoding data from binary data to custom type.
     
     - Parameter data: Binary data from disk.
     - Results: Custom type after decoding if supported.
     */
    func readAnyDataFromFileStorage(data: Data) throws -> Any?
}

/// Conform to protocol if requests support WebServiceFileStorage and store data as files.
public protocol WebServiceRequestValueFileStoring: WebServiceRequestAnyValueFileStoring, WebServiceRequesting {
    /**
     Coding data from custom type to binary data.
     
     - Parameter value: Data with type from response.
     - Results: Binary data after coding if supported.
     */
    func writeDataToFileStorage(value: ResultType) -> Data?
    
    /**
     Decoding data from binary data to custom type.
     
     - Parameter data: Binary data from disk.
     - Results: Custom type after decoding if supported.
     */
    func readDataFromFileStorage(data: Data) throws -> ResultType?
}

public extension WebServiceRequestValueFileStoring {
    func writeAnyDataToFileStorage(value: Any) -> Data? {
        if let value = value as? ResultType {
            return writeDataToFileStorage(value: value)
        } else {
            return nil
        }
    }
    
    func readAnyDataFromFileStorage(data: Data) throws -> Any? {
        return try readDataFromFileStorage(data: data)
    }
}


/// Simple store on disk for WebService.
public class WebServiceFileStorage: WebServiceStorage {
    
    /// Wrapper for store on disk
    public struct StoreData: Codable {
        var binary: Data
        var isRaw: Bool
        var timeStamp: Date?
    }
    
    private let fileWorkDispatchQueue: DispatchQueue
    private let filesDir: URL
    private let prefixNameFiles: String
    
    public let supportDataClassification: Set<AnyHashable>
    public var supportFindFilesUsePrefixNameForDeleteAll = true
    
    // MARK: Constructors
    
    /**
     Constructor with all settings store.
     
     - Parameters:
        - filesDir: Directory for store data.
        - prefixNameFiles: Prefix in name files for all data on disk in this store.
        - supportDataClassification: Data classification support list. Default: support all.
        - filesThreadLabel: Label for DispatchQueue. Optional, need for many WebServiceSimpleFileStorage instances. 
     */
    public init(filesDir: URL, prefixNameFiles: String, supportDataClassification: Set<AnyHashable> = [], filesThreadLabel: String = "ru.provir.WebServiceSimpleFileStorage.filesThread") {
        fileWorkDispatchQueue = DispatchQueue(label: filesThreadLabel,
                                              qos: .background)
        
        self.filesDir = filesDir
        self.prefixNameFiles = prefixNameFiles
        self.supportDataClassification = supportDataClassification
    }
    
    /**
     Constructor with prefix name settings store. Files store in standart caches directory.
     
     - Parameters:
        - prefixNameFiles: Prefix in name files for all data on disk in this store.
        - supportDataClassification: Data classification support list. Default: support all.
     */
    public convenience init?(prefixNameFiles: String, supportDataClassification: Set<AnyHashable> = []) {
        guard let filesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        self.init(filesDir: filesDir, prefixNameFiles: prefixNameFiles, supportDataClassification: supportDataClassification)
    }
    
    /**
     Constructor with default settings store. Files store in standart caches directory.
     
     Prefix name for all files: *webServiceFileStorage_*
     */
    public convenience init?() {
        self.init(prefixNameFiles: "webServiceFileStorage_")
    }
    
    
    // MARK: WebServiceStoraging
    public func isSupportedRequest(_ request: WebServiceBaseRequesting) -> Bool {
        guard let request = request as? WebServiceRequestBaseFileStoring else {
            return false
        }
        
        if request.identificatorForFileStorage != nil &&
            (request is WebServiceRequestRawFileStoring || request is WebServiceRequestAnyValueFileStoring) {
            return true
        } else {
            return false
        }
    }
    
    public func readData(request: WebServiceBaseRequesting, completionHandler: @escaping (Bool, Date?, WebServiceAnyResponse) -> Void) throws {
        guard let request = request as? WebServiceRequestBaseFileStoring, let identificator = request.identificatorForFileStorage else {
            throw WebServiceResponseError.notFoundData
        }
        
        if request.useWrapperWithMetaDataForFileStorage {
            
            //Read StoreData from file
            privateReadStoreData(identificator: identificator, completionHandler: { (storeData, error) in
                if let error = error {
                    //Read error
                    completionHandler(false, nil, .error(error))
        
                } else if let storeData = storeData {
                    if storeData.isRaw {
                        //Readed RAW data - use if supported request
                        if request is WebServiceRequestRawFileStoring {
                            completionHandler(true, storeData.timeStamp, .data(storeData.binary))
                        } else {
                            completionHandler(true, nil, .error(WebServiceResponseError.notFoundData))
                        }
                        
                    } else if let request = request as? WebServiceRequestAnyValueFileStoring {
                        //Readed value and can decode
                        do {
                            if let data = try request.readAnyDataFromFileStorage(data: storeData.binary) {
                                completionHandler(false, storeData.timeStamp, .data(data))
                            } else {
                                completionHandler(false, nil, .error(WebServiceResponseError.notFoundData))
                            }
                        } catch {
                            completionHandler(false, nil, .error(error))
                        }
                        
                    } else {
                        //Value don't supported request
                        completionHandler(false, nil, .error(WebServiceResponseError.notFoundData))
                    }
                    
                } else {
                    //Unknow error
                    completionHandler(false, nil, .error(WebServiceResponseError.notFoundData))
                }
            })
            
        } else {
            //Read binary user data from file
            privateReadBinaryData(identificator: identificator) { (binaryData, error) in
                if let error = error {
                    //Read error
                    completionHandler(false, nil, .error(error))
                    
                } else if let binaryData = binaryData {
                    if let request = request as? WebServiceRequestAnyValueFileStoring {
                        //Readed value and can decode
                        do {
                            if let data = try request.readAnyDataFromFileStorage(data: binaryData) {
                                completionHandler(false, nil, .data(data))
                            } else if request is WebServiceRequestRawFileStoring {
                                //As RAW if can and error
                                completionHandler(true, nil, .data(binaryData))
                            } else {
                                completionHandler(false, nil, .error(WebServiceResponseError.notFoundData))
                            }
                        } catch {
                            if request is WebServiceRequestRawFileStoring {
                                //As RAW if can and error
                                completionHandler(true, nil, .data(binaryData))
                            } else {
                                completionHandler(false, nil, .error(error))
                            }
                        }

                    } else if request is WebServiceRequestRawFileStoring {
                        //Readed RAW data - use if supported request
                        completionHandler(true, nil, .data(binaryData))
                        
                    } else {
                        //Value don't supported request
                        completionHandler(false, nil, .error(WebServiceResponseError.notFoundData))
                    }

                } else {
                    //Unknow error
                    completionHandler(false, nil, .error(WebServiceResponseError.notFoundData))
                }
            }
        }
    }
    
    public func writeData(request: WebServiceBaseRequesting, data: Any, isRaw: Bool) {
        guard let identificator = (request as? WebServiceRequestBaseFileStoring)?.identificatorForFileStorage else {
            return
        }
        
        //Custom
        if let request = request as? WebServiceRequestAnyValueFileStoring {
            if !isRaw, let binaryData = request.writeAnyDataToFileStorage(value: data) {
                
                if request.useWrapperWithMetaDataForFileStorage {
                    let storeData = StoreData(binary: binaryData, isRaw: false, timeStamp: Date())
                    privateWriteStoreData(identificator: identificator, data: storeData)
                } else {
                    privateWriteBinaryData(identificator: identificator, data: binaryData)
                }
            }
        }
        
        //Raw
        else if let request = request as? WebServiceRequestRawFileStoring {
            if isRaw {
                let binaryData: Data
                if let data = data as? Data {
                    binaryData = data
                } else if let binary = (data as? WebServiceRawDataSource)?.binaryRawData {
                    binaryData = binary
                } else {
                    return
                }
                
                if request.useWrapperWithMetaDataForFileStorage {
                    let storeData = StoreData(binary: binaryData, isRaw: true, timeStamp: Date())
                    privateWriteStoreData(identificator: identificator, data: storeData)
                } else {
                    privateWriteBinaryData(identificator: identificator, data: binaryData)
                }
            }
        }
    }
    
    public func deleteData(request: WebServiceBaseRequesting) {
        guard let identificator = (request as? WebServiceRequestBaseFileStoring)?.identificatorForFileStorage else {
            return
        }
        
        let url = filesDir.appendingPathComponent("\(prefixNameFiles)\(identificator)")
        
        fileWorkDispatchQueue.async {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    public func deleteAllData() {
        if !supportFindFilesUsePrefixNameForDeleteAll { return }
        
        fileWorkDispatchQueue.async { [filesDir, prefixNameFiles] in
            guard let urls = try? FileManager.default
                .contentsOfDirectory(at: filesDir,
                                     includingPropertiesForKeys: nil,
                                     options: [.skipsHiddenFiles]) else { return }
            
            for url in urls {
                if url.lastPathComponent.hasPrefix(prefixNameFiles) {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
    }
    

    //MARK: - Storage private
    private func privateReadStoreData(identificator: String, completionHandler: @escaping (StoreData?, Error?) -> Void) {
        let url = filesDir.appendingPathComponent("\(prefixNameFiles)\(identificator)")
        
        fileWorkDispatchQueue.async {
            do {
                if !FileManager.default.fileExists(atPath: url.path) {
                    DispatchQueue.main.async {
                        completionHandler(nil, WebServiceResponseError.notFoundData)
                    }
                    return
                }
                
                let binData = try Data(contentsOf: url)
                var data = try PropertyListDecoder().decode(StoreData.self, from: binData)
                
                if data.timeStamp?.timeIntervalSinceNow ?? -0.1 > 0 {
                    data.timeStamp = nil
                }
                
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
    
    private func privateReadBinaryData(identificator: String, completionHandler: @escaping (Data?, Error?) -> Void) {
        let url = filesDir.appendingPathComponent("\(prefixNameFiles)\(identificator)")

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
    
    private func privateWriteStoreData(identificator: String, data: StoreData) {
        let url = filesDir.appendingPathComponent("\(prefixNameFiles)\(identificator)")
        
        fileWorkDispatchQueue.async {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            
            if let binData = try? encoder.encode(data) {
                try? binData.write(to: url, options: .atomicWrite)
            }
        }
    }
    
    private func privateWriteBinaryData(identificator: String, data: Data) {
        let url = filesDir.appendingPathComponent("\(prefixNameFiles)\(identificator)")
        
        fileWorkDispatchQueue.async {
            try? data.write(to: url, options: .atomicWrite)
        }
    }
}
