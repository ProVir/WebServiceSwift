//
//  WebServiceSimpleFileStorage.swift
//  WebServiceSwift 2.3.0
//
//  Created by ViR (Короткий Виталий) on 29.07.17.
//  Updated to 2.3.0 by ViR (Короткий Виталий) on 25.05.2018.
//  Copyright © 2017 ProVir. All rights reserved.
//

import Foundation


/// Base protocol for requests support store data.
public protocol WebServiceRequestBaseStoring: WebServiceBaseRequesting {
    
    ///Unique identificator for read and write data if current request support storage. Default use for raw data.
    var identificatorForStorage: String? { get }
    
    /// If `true` - use save data for disk as internal type with user data, isRaw flag and timeStamp. Else save only user data binary for disk. Default: true.
    var useWrapperWithMetaDataForStorage: Bool { get }
}

public extension WebServiceRequestBaseStoring {
    var useWrapperWithMetaDataForStorage: Bool { return true }
}

/// Conform to protocol if requests support store raw data.
public protocol WebServiceRequestRawStoring: WebServiceRequestBaseStoring { }

/// Conform to protocol if requests support store data.
public protocol WebServiceRequestAnyValueStoring: WebServiceRequestBaseStoring {
    
    /**
     Coding data from custom type to binary data.
 
     - Parameter value: Data with type from response.
     - Results: Binary data after coding if supported.
     */
    func writeAnyDataToStorage(value: Any) -> Data?
    
    /**
     Decoding data from binary data to custom type.
     
     - Parameter data: Binary data from disk.
     - Results: Custom type after decoding if supported.
     */
    func readAnyDataFromStorage(data: Data) throws -> Any?
}

/// Conform to protocol if requests support store data.
public protocol WebServiceRequestValueStoring: WebServiceRequestAnyValueStoring, WebServiceRequesting {
    /**
     Coding data from custom type to binary data.
     
     - Parameter value: Data with type from response.
     - Results: Binary data after coding if supported.
     */
    func writeDataToStorage(value: ResultType) -> Data?
    
    /**
     Decoding data from binary data to custom type.
     
     - Parameter data: Binary data from disk.
     - Results: Custom type after decoding if supported.
     */
    func readDataFromStorage(data: Data) throws -> ResultType?
}

public extension WebServiceRequestValueStoring {
    func writeAnyDataToStorage(value: Any) -> Data? {
        if let value = value as? ResultType {
            return writeDataToStorage(value: value)
        } else {
            return nil
        }
    }
    
    func readAnyDataFromStorage(data: Data) throws -> Any? {
        return try readDataFromStorage(data: data)
    }
}


/// Data Source from custom types response with raw data from server
public protocol WebServiceRawDataSource {
    var binaryRawData: Data? { get }
}


/// Simple store on disk for WebService.
public class WebServiceSimpleFileStorage: WebServiceStoraging {
    
    public struct StoreData: Codable {
        var binary: Data
        var isRaw: Bool
        var timeStamp: Date?
    }
    
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
        self.init(prefixNameFiles: "webServiceSimpleFileStorage_")
    }
    
    
    // MARK: WebServiceStoraging
    public func isSupportedRequestForStorage(_ request: WebServiceBaseRequesting) -> Bool {
        if (request as? WebServiceRequestBaseStoring)?.identificatorForStorage != nil &&
            (request is WebServiceRequestRawStoring || request is WebServiceRequestAnyValueStoring) {
            return true
        } else {
            return false
        }
    }
    
    public func readData(request: WebServiceBaseRequesting, completionHandler: @escaping (Bool, Date?, WebServiceAnyResponse) -> Void) throws {
        guard let request = request as? WebServiceRequestBaseStoring, let identificator = request.identificatorForStorage else {
            return
        }
        
        if request.useWrapperWithMetaDataForStorage {
            
            //Read StoreData from file
            privateReadStoreData(identificator: identificator, completionHandler: { (storeData, error) in
                if let error = error {
                    //Read error
                    completionHandler(false, nil, .error(error))
        
                } else if let storeData = storeData {
                    if storeData.isRaw {
                        //Readed RAW data - use if supported request
                        if request is WebServiceRequestRawStoring {
                            completionHandler(true, storeData.timeStamp, .data(storeData.binary))
                        } else {
                            completionHandler(true, nil, .error(WebServiceResponseError.notFoundData))
                        }
                        
                    } else if let request = request as? WebServiceRequestAnyValueStoring {
                        //Readed value and can encode
                        do {
                            if let data = try request.readAnyDataFromStorage(data: storeData.binary) {
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
                    if let request = request as? WebServiceRequestAnyValueStoring {
                        //Readed value and can encode
                        do {
                            if let data = try request.readAnyDataFromStorage(data: binaryData) {
                                completionHandler(false, nil, .data(data))
                            } else if request is WebServiceRequestRawStoring {
                                //As RAW if can and error
                                completionHandler(true, nil, .data(binaryData))
                            } else {
                                completionHandler(false, nil, .error(WebServiceResponseError.notFoundData))
                            }
                        } catch {
                            if request is WebServiceRequestRawStoring {
                                //As RAW if can and error
                                completionHandler(true, nil, .data(binaryData))
                            } else {
                                completionHandler(false, nil, .error(error))
                            }
                        }

                    } else if request is WebServiceRequestRawStoring {
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
        guard let identificator = (request as? WebServiceRequestBaseStoring)?.identificatorForStorage else {
            return
        }
        
        //Custom
        if let request = request as? WebServiceRequestAnyValueStoring {
            if !isRaw, let binaryData = request.writeAnyDataToStorage(value: data) {
                
                if request.useWrapperWithMetaDataForStorage {
                    let storeData = StoreData(binary: binaryData, isRaw: false, timeStamp: Date())
                    privateWriteStoreData(identificator: identificator, data: storeData)
                } else {
                    privateWriteBinaryData(identificator: identificator, data: binaryData)
                }
            }
        }
        
        //Raw
        else if let request = request as? WebServiceRequestRawStoring {
            if isRaw {
                let binaryData: Data
                if let data = data as? Data {
                    binaryData = data
                } else if let binary = (data as? WebServiceRawDataSource)?.binaryRawData {
                    binaryData = binary
                } else {
                    return
                }
                
                if request.useWrapperWithMetaDataForStorage {
                    let storeData = StoreData(binary: binaryData, isRaw: true, timeStamp: Date())
                    privateWriteStoreData(identificator: identificator, data: storeData)
                } else {
                    privateWriteBinaryData(identificator: identificator, data: binaryData)
                }
            }
        }
    }

    //MARK: - Storage private
    private func privateReadStoreData(identificator: String, completionHandler: @escaping (StoreData?, Error?) -> Void) {
        let url = filesDir.appendingPathComponent("\(prefixNameFiles)\(identificator)")
        
        fileWorkDispatchQueue.async {
            do {
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
