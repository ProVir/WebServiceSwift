//
//  Tasks.swift
//  WebServiceSwift 4.0.0
//
//  Created by Vitalii Korotkii on 15/08/2019.
//  Copyright © 2019 ProVir. All rights reserved.
//

import Foundation

public enum NetworkTaskState: Hashable, CaseIterable {
    case ready
    case inProgress
    case success
    case failure
    case canceled

    public var isFinished: Bool {
        switch self {
        case .ready, .inProgress: return false
        case .success, .failure, .canceled: return true
        }
    }
}

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

public final class NetworkRequestTask {
    public let request: NetworkBaseRequest
    public let key: NetworkBaseRequestKey?
    public let canRepeat: Bool

    public var storageDependency: NetworkStorageDependency? { return lock.read { self.unsafeStorageDependency } }
    public var state: NetworkTaskState { return lock.read { self.unsafeState } }
    public var canceledReason: NetworkRequestCanceledReason? { return lock.read { self.unsafeCanceledReason } }

    public func setStorageDependency(_ value: NetworkStorageDependency) {
        lock.write { self.unsafeStorageDependency = value }
    }

    public func perform() {
        guard let handler = lock.write({ self.unsafePrepareForPerform() }) else {
            return
        }
        handler(self)
    }

    public func cancel() {
        if state == .inProgress {
            setState(.canceled, canceledReason: .user, finishTask: false)
            workData?.cancelHandler(true, .user)
        }
    }

    init(
        request: NetworkBaseRequest,
        key: NetworkBaseRequestKey?,
        storageDependency: NetworkStorageDependency?,
        canRepeat: Bool,
        performHandler: ((NetworkRequestTask) -> Void)?
    ) {
        self.request = request
        self.key = key
        self.canRepeat = canRepeat

        self.unsafeStorageDependency = storageDependency
        self.unsafePerformHandler = performHandler
    }

    private let lock = DispatchQueueLock(label: "ru.provir.soneta.NetworkRequestTask")
    private var unsafeState: NetworkTaskState = .ready
    private var unsafeCanceledReason: NetworkRequestCanceledReason?
    private var unsafeWorkData: WorkData?
    private var unsafeFinished: Bool = false

    private var unsafeStorageDependency: NetworkStorageDependency?
    private var unsafePerformHandler: ((NetworkRequestTask) -> Void)?

    private func unsafePrepareForPerform() -> ((NetworkRequestTask) -> Void)? {
        if self.state == .ready, let handler = unsafePerformHandler {
            if self.canRepeat == false {
                unsafePerformHandler = nil
            }
            return handler

        } else if self.state.isFinished, self.canRepeat, let handler = unsafePerformHandler {
            self.unsafeRestoreToRepeat()
            self.unsafeState = .ready
            return handler

        } else {
            return nil
        }
    }

    private func unsafeRestoreToRepeat() {
        self.unsafeCanceledReason = nil
        self.unsafeWorkData = nil
        self.unsafeFinished = false
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

    private func unsafePrepareForPerform() -> ((NetworkStorageTask) -> Void)? {
        if self.state == .ready, let handler = unsafePerformHandler {
            unsafePerformHandler = nil
            self.unsafeState = .inProgress
            return handler
        } else {
            return nil
        }
    }
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

extension NetworkRequestTask {
    struct WorkData {
        let requestId: NetworkRequestId
        let gatewayIndex: Int
        let cancelHandler: (_ neededInGatewayCancel: Bool, NetworkRequestCanceledReason) -> Void
    }

    var workData: WorkData? {
        get { return lock.read { self.unsafeWorkData } }
        set { lock.write { self.unsafeWorkData = newValue } }
    }

    var isFinished: Bool {
        return lock.read { unsafeFinished }
    }

    func setState(_ state: NetworkTaskState, canceledReason: NetworkRequestCanceledReason?, finishTask: Bool) {
        let oldState: NetworkTaskState = lock.write {
            let oldState = self.unsafeState

            self.unsafeState = state
            self.unsafeCanceledReason = canceledReason

            if state.isFinished && finishTask {
                self.unsafeFinished = true
                self.unsafeWorkData = nil
            }

            return oldState
        }

        storageDependencyStateHandler(state: state, fromReady: oldState == .ready)
    }

    private func storageDependencyStateHandler(state: NetworkTaskState, fromReady: Bool) {
        guard let storageDependency = storageDependency else { return }

        if storageDependency.shouldCancel(requestState: state) {
            storageDependency.task.cancelFromRequest(reason: canceledReason)

        } else if storageDependency.shouldPerform(requestState: state, fromReady: fromReady) {
            storageDependency.task.perform()
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
