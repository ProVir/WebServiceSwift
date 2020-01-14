//
//  CommonStoring.swift
//  WebServiceSwift 4.0.0
//
//  Created by Короткий Виталий (ViR) on 24/07/2019.
//  Copyright © 2019 ProVir. All rights reserved.
//

import Foundation

/// Protocol for requests with support storages as key -> value use rawData
public protocol NetworkRequestCommonRawStorable: NetworkRequestBaseStorable {
    /// Unique identificator for read and write data, `nil` - request not support storage
    var identificatorForStorage: String? { get }
}

/// Conform to protocol if requests support storages
public protocol NetworkRequestCommonValueStorable: NetworkRequestCommonValueBaseStorable, NetworkRequest {

    /// Unique identificator for read and write data, `nil` - request not support storage
    /*var identificatorForStorage: String? { get }*/

    /**
     Encoding data from response type to binary data.
     Support default implementation when ResponseType is Codable

     - Parameter value: Value from response.
     - Results: Binary data after encoding if supported.
     */
    func encodeToBinaryForStorage(value: ResponseType) throws -> Data

    /**
     Decoding from binary data to custom type.
     Support default implementation when ResponseType is Codable

     - Parameter data: Binary data from storage.
     - Results: Custom type after decoding if supported.
     */
    func decodeToValueFromStorage(binary: Data) throws -> ResponseType
}

/// No generic protocol for requests support storages
public protocol NetworkRequestCommonValueBaseStorable: NetworkRequestBaseStorable {
    /// Unique identificator for read and write data if current request support storage.
    var identificatorForStorage: String? { get }

    func encodeToBinaryForStorage(anyValue: Any) -> Data?
    func decodeToAnyValueFromStorage(binary: Data) throws -> Any?
}

public extension NetworkRequestCommonValueStorable {
    func encodeToBinaryForStorage(anyValue: Any) throws -> Data {
        if let value = anyValue as? ResponseType {
            return try encodeToBinaryForStorage(value: value)
        } else {
            throw NetworkStorageError.invalidTypeResponse(type(of: anyValue), require: ResponseType.self)
        }
    }

    func decodeToAnyValueFromStorage(binary: Data) throws -> Any {
        return try decodeToValueFromStorage(binary: binary)
    }
}

public extension NetworkRequestCommonValueStorable where ResponseType: Codable {
    func encodeToBinaryForStorage(value: ResponseType) throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(value)
    }

    func decodeToValueFromStorage(binary: Data) throws -> ResponseType {
        let decoder = PropertyListDecoder()
        return try decoder.decode(ResponseType.self, from: binary)
    }
}
