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
    /// Type for success response data. For empty data recommended use Void.
    associatedtype ResponseType
}

/// Generic protocol without parameters for server and with information result type for all types request.
public protocol NetworkEmptyRequest: NetworkRequest {
    init()
}

/// Protocol for keys, used for duplicate detect, find and cancel requests
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
/**
 Store policy level for old data when new response. .

 - `anyOfLast`: No delete for any response and save result
 - `onlyLastSuccessResult`: Delete when success response, but failure save
 - `noStoreWhenErrorIsContent`: Delete when response as error with isContent=true or saved error

 */
public enum NetworkRequestStorePolicyLevel: Int {
    case anyOfLast = 0
    case onlyLastSuccessResult
    case noStoreWhenErrorIsContent
}

/// Max age for store responses. Case none - without limit, case default - use value from storage or none.
public enum NetworkRequestStoreAgeLimit {
    case `default`
    case none
    case seconds(TimeInterval)
    case minutes(Int)
    case hours(Int)
    case days(Int)
    case weeks(Int)
}

/// Default data classification for storages.
public let defaultDataClassification = "default"

/// Base protocol for all requests with support storages
public protocol NetworkRequestBaseStorable: NetworkBaseRequest {
    /// Data classification to distinguish between storage. Default - `defaultDataClassification`
    var dataClassificationForStorage: AnyHashable { get }

    /// Store policy level for old data when new response. Default - `onlyLastSuccessResult`.
    var storePolicyLevel: NetworkRequestStorePolicyLevel { get }

    /// Max age for store responses. Default - used value from storage.
    var storeAgeLimit: NetworkRequestStoreAgeLimit { get }
}

public extension NetworkRequestBaseStorable {
    var dataClassificationForStorage: AnyHashable { return defaultDataClassification }
    var storePolicyLevel: NetworkRequestStorePolicyLevel { return .onlyLastSuccessResult }
    var storeAgeLimit: NetworkRequestStoreAgeLimit { return .default }
}


// MARK: Internal
public extension NetworkRequestStoreAgeLimit {
    var isDefault: Bool {
        switch self {
        case .default: return true
        default: return false
        }
    }

    var timeInterval: TimeInterval? {
        switch self {
        case .default, .none: return nil
        case .seconds(let time): return time
        case .minutes(let time): return TimeInterval(time) * 60     //60s
        case .hours(let time): return TimeInterval(time) * 3_600    //60s * 60m
        case .days(let time): return TimeInterval(time) * 86_400    //60s * 60m * 24h
        case .weeks(let time): return TimeInterval(time) * 604_800  //60s * 60m * 24h * 7d
        }
    }
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

