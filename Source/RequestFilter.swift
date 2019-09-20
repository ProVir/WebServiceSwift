//
//  RequestFilter.swift
//  WebServiceSwift
//
//  Created by Vitalii Korotkii on 20/09/2019.
//  Copyright © 2019 ProVir. All rights reserved.
//

import Foundation

// Filter for find requests
public struct NetworkRequestFilter {
    enum Value {
        case request(NetworkBaseRequest)   //BaseRequest & Hashable
        case requestType(NetworkBaseRequest.Type)
        case key(NetworkBaseRequestKey)
        case keyType(NetworkRequestFilterKeyTypeWrapper)  //KeyTypeWrapper<Hashable>
        case and([Value])
        case or([Value])
    }
    let value: Value

    public init<RequestType: NetworkBaseRequest & Hashable>(request: RequestType) { value = .request(request) }
    public init(requestType: NetworkBaseRequest.Type) { value = .requestType(requestType) }
    public init<K: NetworkBaseRequestKey>(key: K) { value = .key(key) }
    public init<K: NetworkBaseRequestKey>(keyType: K.Type) { value = .keyType(KeyTypeWrapper<K>()) }
    public init(and list: [NetworkRequestFilter]) { value = .and(list.map { $0.value }) }
    public init(or list: [NetworkRequestFilter]) { value = .or(list.map { $0.value }) }

    public static func request<RequestType: NetworkBaseRequest & Hashable>(_ request: RequestType) -> NetworkRequestFilter { return .init(request: request) }
    public static func requestType(_ requestType: NetworkBaseRequest.Type) -> NetworkRequestFilter { return .init(requestType: requestType) }
    public static func key<K: NetworkBaseRequestKey>(_ key: K) -> NetworkRequestFilter { return .init(key: key) }
    public static func keyType<K: NetworkBaseRequestKey>(_ keyType: K.Type) -> NetworkRequestFilter { return .init(keyType: keyType) }
    public static func and(_ list: [NetworkRequestFilter]) -> NetworkRequestFilter { return .init(and: list) }
    public static func or(_ list: [NetworkRequestFilter]) -> NetworkRequestFilter { return .init(or: list) }

    struct KeyTypeWrapper<K: NetworkBaseRequestKey>: NetworkRequestFilterKeyTypeWrapper {
        func isEqualType(key: NetworkBaseRequestKey) -> Bool { return key is K }
    }
}

protocol NetworkRequestFilterKeyTypeWrapper {
    func isEqualType(key: NetworkBaseRequestKey) -> Bool
}

struct NetworkRequestKeyWrapper: Hashable {
    let key: NetworkBaseRequestKey

    func hash(into hasher: inout Hasher) {
        key.hash(into: &hasher)
    }

    static func == (lhs: NetworkRequestKeyWrapper, rhs: NetworkRequestKeyWrapper) -> Bool {
        return lhs.key.isEqual(rhs.key)
    }
}
