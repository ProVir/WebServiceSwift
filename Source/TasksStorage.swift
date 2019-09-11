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

    private var tasks: [UInt64: RequestTask] = [:]               //All requests
    private var mapRequestTypes: [String: Set<UInt64>] = [:]        //[Request.Type: [Id]]
    private var mapRequestHashs: [AnyHashable: Set<UInt64>] = [:]   //[Request<Hashable>: [Id]]
    private var mapRequestKeys:  [AnyHashable: Set<UInt64>] = [:]   //[Key: [Id]]

    func addTask(requestId: UInt64, task: RequestTask) {
        mutex.lock()
        defer { mutex.unlock() }

        tasks[requestId] = task
        mapRequestTypes[keyForMapRequestTypes(task), default: Set<UInt64>()].insert(requestId)

        if let key = keyForMapRequestHashs(task) {
            mapRequestHashs[key, default: Set<UInt64>()].insert(requestId)
        }

        if let key = keyForMapRequestKeys(task) {
            mapRequestKeys[key, default: Set<UInt64>()].insert(requestId)
        }
    }

    func removeTask(requestId: UInt64) {
        mutex.lock()
        defer { mutex.unlock() }

        guard let task = tasks.removeValue(forKey: requestId) else { return }
        removeFromMapRequest(&mapRequestTypes, key: keyForMapRequestTypes(task), requestId: requestId)
        removeFromMapRequest(&mapRequestHashs, key: keyForMapRequestHashs(task), requestId: requestId)
        removeFromMapRequest(&mapRequestKeys, key: keyForMapRequestKeys(task), requestId: requestId)
    }

    func allTasks() -> [(requestId: UInt64, task: RequestTask)] {
        return mutex.synchronized {
            tasks.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
        }
    }

    func fetch(requestId: UInt64) -> RequestTask? {
        return mutex.synchronized { tasks[requestId] }
    }

    func containsDuplicate(task: RequestTask) -> Bool {
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

    func tasks(filter: RequestFilter?) -> [RequestTask] {
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

    func contains(filter: RequestFilter?) -> Bool {
        return mutex.synchronized {
            if let filter = filter {
                return self.findIds(use: filter.value, onlyFirst: true).isEmpty == false
            } else {
                return tasks.isEmpty == false
            }
        }
    }



    // MARK: - Private
    private func keyForMapRequestTypes(_ task: RequestTask) -> String {
        return "\(type(of: task.request))"
    }

    private func keyForMapRequestTypes(_ requestType: BaseRequest.Type) -> String {
        return "\(requestType)"
    }

    private func keyForMapRequestHashs(_ task: RequestTask) -> AnyHashable? {
        return task.request as? AnyHashable
    }

    private func keyForMapRequestHashs(_ request: BaseRequest) -> AnyHashable? {
        return request as? AnyHashable
    }

    private func keyForMapRequestKeys(_ task: RequestTask) -> AnyHashable? {
        return task.key
    }

    private func removeFromMapRequest<K: Hashable>(_ map: inout [K: Set<UInt64>], key: K?, requestId: UInt64) {
        guard let key = key, var ids = map[key] else { return }

        ids.remove(requestId)
        if ids.isEmpty {
            map.removeValue(forKey: key)
        } else {
            map[key] = ids
        }
    }

    // MARK: Find use filter
    private func findIds(use filter: RequestFilter.Value, onlyFirst: Bool) -> Set<UInt64> {
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

    private func findIds(request: BaseRequest) -> Set<UInt64> {
        guard let key = keyForMapRequestHashs(request) else { return [] }
        return mapRequestHashs[key] ?? []
    }

    private func findIds(requestType: BaseRequest.Type) -> Set<UInt64> {
        let key = keyForMapRequestTypes(requestType)
        return mapRequestTypes[key] ?? []
    }

    private func findIds(key: AnyHashable) -> Set<UInt64> {
        return mapRequestKeys[key] ?? []
    }

    private func findIds(keyType wrapper: RequestFilterKeyTypeWrapper, onlyFirst: Bool) -> Set<UInt64> {
        var ids = Set<UInt64>()
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
