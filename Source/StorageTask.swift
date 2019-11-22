//
//  StorageTask.swift
//  WebServiceSwift
//
//  Created by Vitalii Korotkii on 22/11/2019.
//  Copyright © 2019 ProVir. All rights reserved.
//

import Foundation

public struct NetworkStorageDependency {
    public enum PerformPolicy {
        case auto
        case manual
        case requestFailure
        case requestFailureOrCanceled
    }

    public enum CancelPolicy {
        case requestSuccess
        case requestSuccessOrCanceled
    }

    public let task: NetworkStorageTask
    public let performPolicy: PerformPolicy
    public let cancelPolicy: CancelPolicy

    public init(task: NetworkStorageTask, cancelPolicy: CancelPolicy = .requestSuccess, performPolicy: PerformPolicy = .auto) {
        self.task = task
        self.cancelPolicy = cancelPolicy
        self.performPolicy = performPolicy
    }
}

public final class NetworkStorageTask {
    public enum CanceledReason {
        case user
        case request(NetworkTaskState, NetworkRequestCanceledReason?)
    }

    public let request: NetworkRequestBaseStorable

    public var state: NetworkTaskState { return lock.read { self.unsafeState } }
    public var canceledReason: CanceledReason? { return lock.read { self.unsafeCanceledReason } }

    public func perform() {
        guard let handler = lock.write({ self.unsafePrepareForPerform() }) else {
            return
        }
        handler(self)
    }

    public func cancel() {
        lock.write {
            self.unsafeState = .canceled
            self.unsafeCanceledReason = .user
        }
    }

    init(
        request: NetworkRequestBaseStorable,
        beginState: NetworkTaskState,
        performHandler: ((NetworkStorageTask) -> Void)?
    ) {
        self.request = request
        self.unsafeState = beginState
        self.unsafePerformHandler = performHandler
    }

    private let lock = DispatchQueueLock(label: "ru.provir.soneta.NetworkStorageTask")
    private var unsafeState: NetworkTaskState = .ready
    private var unsafeCanceledReason: CanceledReason?

    private var unsafePerformHandler: ((NetworkStorageTask) -> Void)?
}

// MARK: - Internal
extension NetworkStorageDependency {
    func shouldPerform(requestState state: NetworkTaskState, fromReady: Bool) -> Bool {
        switch performPolicy {
        case .auto: return state == .inProgress || fromReady
        case .manual: return false
        case .requestFailure: return state == .failure
        case .requestFailureOrCanceled: return state == .failure || state == .canceled
        }
    }

    func shouldCancel(requestState state: NetworkTaskState) -> Bool {
        switch cancelPolicy {
        case .requestSuccess: return state == .success
        case .requestSuccessOrCanceled: return state == .success || state == .canceled
        }
    }
}

extension NetworkStorageTask {
    var isCanceled: Bool {
        return lock.read { unsafeState == .canceled }
    }

    var requestCanceledReason: NetworkRequestCanceledReason {
        switch canceledReason {
        case .some(.request(_, let reason)): return reason ?? .unknown
        default: return .unknown
        }
    }

    var storageCanceledReason: NetworkStorageCanceledReason {
        guard let reason = canceledReason else { return .unknown }
        switch reason {
        case .user: return .user
        case .request(.success, _): return .dependSuccess
        case .request(.failure, _): return .dependFailure
        case .request(_, .some(let r)): return .dependCanceled(r)
        case .request(_, .none): return .unknown
        }
    }

    func setStateFromStorage(_ state: NetworkTaskState) {
        lock.write {
            self.unsafeState = state
        }
    }

    func cancelFromRequest(reason: NetworkRequestCanceledReason?) {
        lock.write {
            self.unsafeState = .canceled
            self.unsafeCanceledReason = .request(state, reason)
        }
    }
}

private extension NetworkStorageTask {
    func unsafePrepareForPerform() -> ((NetworkStorageTask) -> Void)? {
        if self.state == .ready, let handler = unsafePerformHandler {
            unsafePerformHandler = nil
            self.unsafeState = .inProgress
            return handler
        } else {
            return nil
        }
    }
}
