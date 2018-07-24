//
//  WebServiceRequestGeneralStoring.swift
//  WebServiceSwift
//
//  Created by Короткий Виталий on 24.07.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation

/// Base protocol for requests support many storages.
public protocol WebServiceRequestBaseGeneralStoring:
                    WebServiceRequestBaseFileStoring, WebServiceRequestDataBaseStoring, WebServiceRequestMemoryStoring {
    
    /// Unique identificator for read and write data if current request support storage.
    var identificatorForStorage: String? { get }
}

/// Conform to protocol if requests support many storages and store raw data.
public protocol WebServiceRequestRawGeneralStoring: WebServiceRequestBaseGeneralStoring,
                    WebServiceRequestRawFileStoring, WebServiceRequestRawDataBaseStoring { }

/// Conform to protocol if requests support many storages and store data.
public protocol WebServiceRequestValueGeneralStoring: WebServiceRequestBaseGeneralStoring,
                    WebServiceRequestValueFileStoring, WebServiceRequestValueDataBaseStoring {
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


//MARK: Support WebServiceFileStorage
public extension WebServiceRequestBaseGeneralStoring {
    var identificatorForFileStorage: String? {
        return identificatorForStorage
    }
}

public extension WebServiceRequestValueGeneralStoring {
    func writeDataToFileStorage(value: ResultType) -> Data? {
        return writeDataToStorage(value: value)
    }
    
    func readDataFromFileStorage(data: Data) throws -> ResultType? {
        return try readDataFromStorage(data: data)
    }
}


//MARK: Support WebServiceDataBaseStorage
public extension WebServiceRequestBaseGeneralStoring {
    var identificatorForDataBaseStorage: String? {
        return identificatorForStorage
    }
}

public extension WebServiceRequestValueGeneralStoring {
    func writeDataToDataBaseStorage(value: ResultType) -> Data? {
        return writeDataToStorage(value: value)
    }
    
    func readDataFromDataBaseStorage(data: Data) throws -> ResultType? {
        return try readDataFromStorage(data: data)
    }
}

//MARK: Support WebServiceMemoryStorage
public extension WebServiceRequestBaseGeneralStoring {
    var keyForMemoryStorage: AnyHashable? {
        return identificatorForStorage
    }
}


