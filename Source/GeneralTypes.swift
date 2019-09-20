//
//  GatewayTypes.swift
//  WebServiceSwift
//
//  Created by Vitalii Korotkii on 20/09/2019.
//  Copyright © 2019 ProVir. All rights reserved.
//

import Foundation

/// RawData for Gateway
public protocol NetworkStorageRawData { }
extension Data: NetworkStorageRawData { }

/// RequestId for gateway
public struct NetworkRequestId: RawRepresentable, Hashable, Comparable {
    public let value: UInt64
    public init(_ value: UInt64) {
        self.value = value
    }

    public init?(rawValue: UInt64) {
        self.value = rawValue
    }

    public var rawValue: UInt64 {
        return value
    }

    public static func < (lhs: NetworkRequestId, rhs: NetworkRequestId) -> Bool {
        return lhs.value < rhs.value
    }
}

/// Response from gateway when success
public struct NetworkGatewayResponse {
    let result: Any
    let rawDataForStorage: NetworkStorageRawData?

    public init(result: Any, rawDataForStorage: NetworkStorageRawData?) {
        self.result = result
        self.rawDataForStorage = rawDataForStorage
    }
}

/// Response from storage
public enum NetworkStorageFetchResponse {
    case rawData(NetworkStorageRawData, Date?)
    case value(Any, Date?)
    case notFound
    case failure(Error)
}
