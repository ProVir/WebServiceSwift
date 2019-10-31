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

    func shouldPerform(requestState state: NetworkTaskState) -> Bool {
        switch performPolicy {
        case .auto: return state == .inProgress
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

public final class NetworkRequestTask {
    public let request: NetworkBaseRequest
    public let key: NetworkBaseRequestKey?
    public let canRepeat: Bool

    public var storageDependency: NetworkStorageDependency? { return mutex.synchronized { self.unsafeStorageDependency } }
    public var state: NetworkTaskState { return mutex.synchronized { self.unsafeState } }
    public var canceledReason: NetworkRequestCanceledReason? { return mutex.synchronized { self.unsafeCanceledReason } }

    public func setStorageDependency(_ value: NetworkStorageDependency) {
        mutex.synchronized { self.unsafeStorageDependency = value }
    }

    public func perform() {
        guard let (handler, state) = mutex.synchronized({ self.unsafePrepareForPerform() }) else { return }

        storageDependencyStateHandler(state: state)
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
        beginState: NetworkTaskState,
        performHandler: ((NetworkRequestTask) -> Void)?
    ) {
        self.request = request
        self.key = key
        self.canRepeat = canRepeat

        self.unsafeStorageDependency = storageDependency
        self.unsafeState = beginState
        self.unsafePerformHandler = performHandler
    }

    private let mutex = PThreadMutexLock()
    private var unsafeState: NetworkTaskState
    private var unsafeCanceledReason: NetworkRequestCanceledReason?
    private var unsafeWorkData: WorkData?
    private var unsafeFinished: Bool = false

    private var unsafeStorageDependency: NetworkStorageDependency?
    private var unsafePerformHandler: ((NetworkRequestTask) -> Void)?

    private func unsafePrepareForPerform() -> ((NetworkRequestTask) -> Void, NetworkTaskState)? {
        if self.state == .ready, let handler = unsafePerformHandler {
            if self.canRepeat == false {
                unsafePerformHandler = nil
            }
            self.unsafeState = .inProgress
            return (handler, .inProgress)

        } else if self.state.isFinished, self.canRepeat, let handler = unsafePerformHandler {
            self.unsafeRestoreToRepeat()
            self.unsafeState = .inProgress
            return (handler, .inProgress)

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

    public var state: NetworkTaskState { return mutex.synchronized { self.unsafeState } }
    public var canceledReason: CanceledReason? { return mutex.synchronized { self.unsafeCanceledReason } }

    public func perform() {
        guard let handler = mutex.synchronized({ self.unsafePrepareForPerform() }) else { return }
        handler(self)
    }

    public func cancel() {
        mutex.synchronized {
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

    private let mutex = PThreadMutexLock()
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
extension NetworkRequestTask {
    struct WorkData {
        let requestId: NetworkRequestId
        let gatewayIndex: Int
        let cancelHandler: (_ neededInGatewayCancel: Bool, NetworkRequestCanceledReason) -> Void
    }

    var workData: WorkData? {
        get { return mutex.synchronized { self.unsafeWorkData } }
        set { mutex.synchronized { self.unsafeWorkData = newValue } }
    }

    var isFinished: Bool {
        return mutex.synchronized { unsafeFinished }
    }

    func setState(_ state: NetworkTaskState, canceledReason: NetworkRequestCanceledReason?, finishTask: Bool) {
        mutex.synchronized {
            self.unsafeState = state
            self.unsafeCanceledReason = canceledReason

            if state.isFinished && finishTask {
                self.unsafeFinished = true
                self.unsafeWorkData = nil
            }
        }

        storageDependencyStateHandler(state: state)
    }

    func storageDependencyStateHandler(state: NetworkTaskState) {
        guard let storageDependency = storageDependency else { return }

        if storageDependency.shouldCancel(requestState: state) {
            storageDependency.task.cancelFromRequest(reason: canceledReason)

        } else if storageDependency.shouldPerform(requestState: state) {
            storageDependency.task.perform()
        }
    }
}

extension NetworkStorageTask {
    var isCanceled: Bool {
        return mutex.synchronized { unsafeState == .canceled }
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
        mutex.synchronized {
            self.unsafeState = state
        }
    }

    func cancelFromRequest(reason: NetworkRequestCanceledReason?) {
        mutex.synchronized {
            self.unsafeState = .canceled
            self.unsafeCanceledReason = .request(state, reason)
        }
    }
}
