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

/// Result from gateway when success
public enum NetworkGatewayResult {
    case success(Any, rawDataForStorage: NetworkStorageRawData?)
    case failure(Error, isContent: Bool)

    public static func failureCommon(_ error: Error) -> NetworkGatewayResult {
        return .failure(error, isContent: false)
    }

    public static func failureAsContent(_ error: Error) -> NetworkGatewayResult {
        return .failure(error, isContent: true)
    }
}

/// Response from storage
public enum NetworkStorageFetchResult {
    case rawData(NetworkStorageRawData, saved: Date?)
    case value(Any, Date?)
    case notFound
    case failure(Error)
}

/// Response from storage
public enum NetworkStorageSaveResult {
    case success
    case notSupport
    case failure(Error)
}
