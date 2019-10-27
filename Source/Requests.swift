//
//  Requests.swift
//  WebServiceSwift
//
//  Created by Vitalii Korotkii on 20/09/2019.
//  Copyright © 2019 ProVir. All rights reserved.
//

import Foundation

/// Base protocol for all types request.
public protocol NetworkBaseRequest { }

/// Generic protocol with information result type for all types request.
public protocol NetworkRequest: NetworkBaseRequest {
    /// Type for response data when success. For data without data you can use Void or Any?
    associatedtype ResponseType
}

/// Generic protocol without parameters for server and with information result type for all types request.
public protocol NetworkEmptyRequest: NetworkRequest {
    init()
}

public protocol NetworkRequestKey: NetworkBaseRequestKey, Hashable { }

public protocol NetworkBaseRequestKey {
    func hash(into hasher: inout Hasher)
    func isEqual(_ key: NetworkBaseRequestKey) -> Bool
}

public extension NetworkRequestKey {
    func isEqual(_ key: NetworkBaseRequestKey) -> Bool {
        guard let key = key as? Self else { return false }
        return key == self
    }
}


// MARK: Storage
public enum NetworkRequestStorePolicyLevel: Int {
    case anyOfLast = 0
    case onlyLastSuccessResult
    case noStoreWhenErrorIsContent
}

/// Default data classification for storages.
public let defaultDataClassification = "default"

/// Base protocol for all requests with support storages
public protocol NetworkRequestBaseStorable: NetworkBaseRequest {
    /// Data classification to distinguish between storage
    var dataClassificationForStorage: AnyHashable { get }

    var storePolicyLevel: NetworkRequestStorePolicyLevel { get }
}

public extension NetworkRequestBaseStorable {
    var dataClassificationForStorage: AnyHashable { return defaultDataClassification }
    var storePolicyLevel: NetworkRequestStorePolicyLevel { return .onlyLastSuccessResult }
}


extension NetworkRequestStorePolicyLevel {
    func shouldDeleteWhenFailureSave() -> Bool {
        switch self {
        case .anyOfLast: return false
        case .onlyLastSuccessResult,
             .noStoreWhenErrorIsContent: return true
        }
    }

    func shouldDeleteWhenErrorIsContent() -> Bool {
        switch self {
        case .anyOfLast,
             .onlyLastSuccessResult: return false
        case .noStoreWhenErrorIsContent: return true
        }
    }
}
