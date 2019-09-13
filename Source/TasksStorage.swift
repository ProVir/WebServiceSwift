//
//  GatewayTasksStorage.swift
//  WebServiceSwift
//
//  Created by Vitalii Korotkii on 04/09/2019.
//  Copyright © 2019 ProVir. All rights reserved.
//

import Foundation

final class TasksStorage {
    private let mutex = PThreadMutexLock()

    private var tasks: [NetworkRequestId: NetworkRequestTask] = [:]               //All requests
    private var mapRequestTypes: [String: Set<NetworkRequestId>] = [:]        //[Request.Type: [Id]]
    private var mapRequestHashs: [AnyHashable: Set<NetworkRequestId>] = [:]   //[Request<Hashable>: [Id]]
    private var mapRequestKeys:  [AnyHashable: Set<NetworkRequestId>] = [:]   //[Key: [Id]]

    func addTask(requestId: NetworkRequestId, task: NetworkRequestTask) {
        mutex.lock()
        defer { mutex.unlock() }

        tasks[requestId] = task
        mapRequestTypes[keyForMapRequestTypes(task), default: []].insert(requestId)

        if let key = keyForMapRequestHashs(task) {
            mapRequestHashs[key, default: []].insert(requestId)
        }

        if let key = keyForMapRequestKeys(task) {
            mapRequestKeys[key, default: []].insert(requestId)
        }
    }

    func removeTask(requestId: NetworkRequestId) {
        mutex.lock()
        defer { mutex.unlock() }

        guard let task = tasks.removeValue(forKey: requestId) else { return }
        removeFromMapRequest(&mapRequestTypes, key: keyForMapRequestTypes(task), requestId: requestId)
        removeFromMapRequest(&mapRequestHashs, key: keyForMapRequestHashs(task), requestId: requestId)
        removeFromMapRequest(&mapRequestKeys, key: keyForMapRequestKeys(task), requestId: requestId)
    }

    func allTasks() -> [(requestId: NetworkRequestId, task: NetworkRequestTask)] {
        return mutex.synchronized {
            tasks.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
        }
    }

    func fetch(requestId: NetworkRequestId) -> NetworkRequestTask? {
        return mutex.synchronized { tasks[requestId] }
    }

    func containsDuplicate(task: NetworkRequestTask) -> Bool {
        if let key = task.key {
            return mutex.synchronized {
                (mapRequestKeys[key]?.isEmpty ?? true) == false
            }
        } else if let key = keyForMapRequestHashs(task) {
            return mutex.synchronized {
                (mapRequestHashs[key]?.isEmpty ?? true) == false
            }
        } else {
            return false
        }
    }

    func tasks(filter: NetworkRequestFilter?) -> [NetworkRequestTask] {
        return mutex.synchronized {
            if let filter = filter {
                return findIds(use: filter.value, onlyFirst: false)
                    .sorted(by: <)
                    .compactMap { tasks[$0] }
            } else {
                return tasks.sorted { $0.key < $1.key }.map { $0.value }
            }
        }
    }

    func contains(filter: NetworkRequestFilter?) -> Bool {
        return mutex.synchronized {
            if let filter = filter {
                return self.findIds(use: filter.value, onlyFirst: true).isEmpty == false
            } else {
                return tasks.isEmpty == false
            }
        }
    }



    // MARK: - Private
    private func keyForMapRequestTypes(_ task: NetworkRequestTask) -> String {
        return "\(type(of: task.request))"
    }

    private func keyForMapRequestTypes(_ requestType: BaseNetworkRequest.Type) -> String {
        return "\(requestType)"
    }

    private func keyForMapRequestHashs(_ task: NetworkRequestTask) -> AnyHashable? {
        return task.request as? AnyHashable
    }

    private func keyForMapRequestHashs(_ request: BaseNetworkRequest) -> AnyHashable? {
        return request as? AnyHashable
    }

    private func keyForMapRequestKeys(_ task: NetworkRequestTask) -> AnyHashable? {
        return task.key
    }

    private func removeFromMapRequest<K: Hashable>(_ map: inout [K: Set<NetworkRequestId>], key: K?, requestId: NetworkRequestId) {
        guard let key = key, var ids = map[key] else { return }

        ids.remove(requestId)
        if ids.isEmpty {
            map.removeValue(forKey: key)
        } else {
            map[key] = ids
        }
    }

    // MARK: Find use filter
    private func findIds(use filter: NetworkRequestFilter.Value, onlyFirst: Bool) -> Set<NetworkRequestId> {
        switch filter {
        case let .request(request): return findIds(request: request)
        case let .requestType(requestType): return findIds(requestType: requestType)
        case let .key(key): return findIds(key: key)
        case let .keyType(keyType): return findIds(keyType: keyType, onlyFirst: onlyFirst)
        case let .and(list):
            return list.reduce([]) {
                let ids = self.findIds(use: $1, onlyFirst: false)
                return $0.intersection(ids)
            }

        case let .or(list):
            return list.reduce([]) {
                if onlyFirst && $0.isEmpty == false { return $0 }
                let ids = self.findIds(use: $1, onlyFirst: onlyFirst)
                return $0.union(ids)
            }
        }
    }

    private func findIds(request: BaseNetworkRequest) -> Set<NetworkRequestId> {
        guard let key = keyForMapRequestHashs(request) else { return [] }
        return mapRequestHashs[key] ?? []
    }

    private func findIds(requestType: BaseNetworkRequest.Type) -> Set<NetworkRequestId> {
        let key = keyForMapRequestTypes(requestType)
        return mapRequestTypes[key] ?? []
    }

    private func findIds(key: AnyHashable) -> Set<NetworkRequestId> {
        return mapRequestKeys[key] ?? []
    }

    private func findIds(keyType wrapper: NetworkRequestFilterKeyTypeWrapper, onlyFirst: Bool) -> Set<NetworkRequestId> {
        var ids = Set<NetworkRequestId>()
        for (requestKey, requestIds) in mapRequestKeys {
            if wrapper.isEqualType(key: requestKey.base) {
                if onlyFirst {
                    return requestIds
                } else {
                    ids.formUnion(requestIds)
                }
            }
        }
        return ids
    }
}
