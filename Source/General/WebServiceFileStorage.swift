//
//  WebServiceFileStorage.swift
//  WebServiceSwift 4.0.0
//
//  Created by Короткий Виталий (ViR) on 29.07.17.
//  Updated to 3.0.0 by Короткий Виталий (ViR) on 04.09.2018.
//  Copyright © 2017 - 2018 ProVir. All rights reserved.
//

import Foundation


/// Simple store on disk for WebService.
public class WebServiceFileStorage: WebServiceStorage {
    
    /// Wrapper for store on disk
    public struct StoreData: Codable {
        var binary: Data
        var isRaw: Bool
        var timeStamp: Date?
    }

    /**
     Format store data on disk

     - `autoWithMeta`: Store value or raw with information of type and timestamp, as default
     - `binaryValue`: Store only binary value without meta
     - `binaryRaw`: Store only binary raw data without meta
     */
    public enum StoreFormat {
        case autoWithMeta
        case binaryValue
        case binaryRaw
    }
    
    private let fileWorkDispatchQueue: DispatchQueue
    private let filesDir: URL
    private let prefixNameFiles: String
    private let storeFormat: StoreFormat
    
    public let supportDataClassification: Set<AnyHashable>?
    public var supportFindFilesUsePrefixNameForDeleteAll = true
    
    // MARK: Constructors
    
    /**
     Constructor with all settings store.
     
     - Parameters:
        - filesDir: Directory for store data.
        - prefixNameFiles: Prefix in name files for all data on disk in this store.
        - useWrapperWithMetaData: When true save data for disk as internal type with user data, else only binary data without meta. Default - true.
        - supportDataClassification: Data classification support list. Default: support all.
     */
    public init(filesDir: URL, prefixNameFiles: String, storeFormat: StoreFormat = .autoWithMeta, supportDataClassification: Set<AnyHashable>? = nil) {
        fileWorkDispatchQueue = DispatchQueue(label: "ru.provir.WebServiceFileStorage.filesThread",
                                              qos: .background)
        
        self.filesDir = filesDir
        self.prefixNameFiles = prefixNameFiles
        self.supportDataClassification = supportDataClassification
        self.storeFormat = storeFormat
    }
    
    /**
     Constructor with prefix name settings store. Files store in standart caches directory.
     
     - Parameters:
        - prefixNameFiles: Prefix in name files for all data on disk in this store.
        - supportDataClassification: Data classification support list. Default: support all.
     */
    public convenience init?(prefixNameFiles: String, supportDataClassification: Set<AnyHashable>? = nil) {
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
        guard let request = request as? WebServiceRequestEasyStoring else {
            return false
        }

        return request.identificatorForStorage != nil
    }
    
    public func fetch(request: WebServiceBaseRequesting, completionHandler: @escaping (WebServiceStorageResponse) -> Void) {
        guard let request = request as? WebServiceRequestEasyStoring, let identificator = request.identificatorForStorage else {
            completionHandler(.error(WebServiceResponseError.notFoundData))
            return
        }

        switch storeFormat {
        case .autoWithMeta:
            readStoreData(identificator: identificator) { result in
                switch result {
                case .success(let storeData):
                    if storeData.isRaw {
                        completionHandler(.rawData(storeData.binary, storeData.timeStamp))

                    } else if let request = request as? WebServiceRequestBinaryValueBaseStoring {
                        do {
                            if let value = try request.decodeToAnyValueFromStorage(binary: storeData.binary) {
                                completionHandler(.value(value, storeData.timeStamp))
                            } else {
                                completionHandler(.error(WebServiceResponseError.notFoundData))
                            }
                        } catch {
                            completionHandler(.error(error))
                        }

                    } else {
                        completionHandler(.error(WebServiceResponseError.notFoundData))
                    }

                case .failure(let error):
                    completionHandler(.error(error))
                }
            }

        case .binaryValue:
            readBinaryData(identificator: identificator) { result in
                switch result {
                case .success(let binaryData):
                    if let request = request as? WebServiceRequestBinaryValueBaseStoring {
                        do {
                            if let value = try request.decodeToAnyValueFromStorage(binary: binaryData) {
                                completionHandler(.value(value, nil))
                            } else {
                                completionHandler(.error(WebServiceResponseError.notFoundData))
                            }
                        } catch {
                            completionHandler(.error(error))
                        }
                    } else {
                        completionHandler(.error(WebServiceResponseError.notFoundData))
                    }

                case .failure(let error):
                    completionHandler(.error(error))
                }
            }

        case .binaryRaw:
            readBinaryData(identificator: identificator) { result in
                switch result {
                case .success(let binaryData):
                    completionHandler(.rawData(binaryData, nil))

                case .failure(let error):
                    completionHandler(.error(error))
                }
            }
        }
    }

    public func save(request: WebServiceBaseRequesting, rawData: WebServiceStorageRawData?, value: Any) {
        guard let identificator = (request as? WebServiceRequestEasyStoring)?.identificatorForStorage else {
            return
        }

        switch storeFormat {
        case .autoWithMeta:
            let timeStamp = Date()
            if let request = request as? WebServiceRequestBinaryValueBaseStoring,
               let binaryData = request.encodeToBinaryForStorage(anyValue: value) {
                let storeData = StoreData(binary: binaryData, isRaw: false, timeStamp: timeStamp)
                writeStoreData(identificator: identificator, data: storeData)

            } else if let binaryData = rawData as? Data {
                //Raw
                let storeData = StoreData(binary: binaryData, isRaw: false, timeStamp: timeStamp)
                writeStoreData(identificator: identificator, data: storeData)
            }

        case .binaryValue:
            if let request = request as? WebServiceRequestBinaryValueBaseStoring,
               let binaryData = request.encodeToBinaryForStorage(anyValue: value) {
                writeBinaryData(identificator: identificator, data: binaryData)
            }

        case .binaryRaw:
            if let binaryData = rawData as? Data {
                writeBinaryData(identificator: identificator, data: binaryData)
            }
        }
    }
    
    public func delete(request: WebServiceBaseRequesting) {
        guard let identificator = (request as? WebServiceRequestEasyStoring)?.identificatorForStorage else {
            return
        }
        
        let url = filesDir.appendingPathComponent("\(prefixNameFiles)\(identificator)")
        
        fileWorkDispatchQueue.async {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    public func deleteAll() {
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
    private func readStoreData(identificator: String, completion: @escaping (Result<StoreData, Error>) -> Void) {
        let url = filesDir.appendingPathComponent("\(prefixNameFiles)\(identificator)")
        
        fileWorkDispatchQueue.async {
            do {
                if !FileManager.default.fileExists(atPath: url.path) {
                    completion(.failure(WebServiceResponseError.notFoundData))
                    return
                }
                
                let binData = try Data(contentsOf: url)
                var data = try PropertyListDecoder().decode(StoreData.self, from: binData)
                
                if data.timeStamp?.timeIntervalSinceNow ?? -0.1 > 0 {
                    data.timeStamp = nil
                }
                
                completion(.success(data))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    private func readBinaryData(identificator: String, completion: @escaping (Result<Data, Error>) -> Void) {
        let url = filesDir.appendingPathComponent("\(prefixNameFiles)\(identificator)")

        fileWorkDispatchQueue.async {
            do {
                let data = try Data(contentsOf: url)
                completion(.success(data))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    private func writeStoreData(identificator: String, data: StoreData) {
        let url = filesDir.appendingPathComponent("\(prefixNameFiles)\(identificator)")
        
        fileWorkDispatchQueue.async {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            
            if let binData = try? encoder.encode(data) {
                try? binData.write(to: url, options: .atomicWrite)
            }
        }
    }
    
    private func writeBinaryData(identificator: String, data: Data) {
        let url = filesDir.appendingPathComponent("\(prefixNameFiles)\(identificator)")
        
        fileWorkDispatchQueue.async {
            try? data.write(to: url, options: .atomicWrite)
        }
    }
}
