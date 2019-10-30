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
    public enum Regime {
        case dependSuccessResult
        case dependFull
    }

    public let task: NetworkStorageTask
    public let regime: Regime

    init(task: NetworkStorageTask, regime: Regime = .dependSuccessResult) {
        self.task = task
        self.regime = regime
    }

    func shouldCancel(requestState state: NetworkTaskState) -> Bool {
        switch regime {
        case .dependSuccessResult: return state == .success
        case .dependFull: return state == .success || state == .canceled
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
        let handler = mutex.synchronized { self.unsafeHandlerForPerform() }
        handler?(self)
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

    private func unsafeHandlerForPerform() -> ((NetworkRequestTask) -> Void)? {
        if self.state == .ready, let handler = unsafePerformHandler {
            if self.canRepeat == false {
                unsafePerformHandler = nil
            }
            self.unsafeState = .inProgress
            return handler

        } else if self.state.isFinished, self.canRepeat, let handler = unsafePerformHandler {
            self.unsafeRestoreToRepeat()
            self.unsafeState = .inProgress
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

    public let request: NetworkBaseRequest

    public var state: NetworkTaskState { return mutex.synchronized { self.unsafeState } }
    public var canceledReason: CanceledReason? { return mutex.synchronized { self.unsafeCanceledReason } }

    public func cancel() {
        mutex.synchronized {
            self.unsafeState = .canceled
            self.unsafeCanceledReason = .user
        }
    }

    init(request: NetworkBaseRequest) {
        self.request = request
    }

    private let mutex = PThreadMutexLock()
    private var unsafeState: NetworkTaskState = .ready
    private var unsafeCanceledReason: CanceledReason?
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

        if let storageDependency = storageDependency, storageDependency.shouldCancel(requestState: state) {
            storageDependency.task.cancelFromRequest(reason: canceledReason)
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
