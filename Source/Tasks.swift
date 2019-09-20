//
//  Tasks.swift
//  WebServiceSwift 4.0.0
//
//  Created by Vitalii Korotkii on 15/08/2019.
//  Copyright © 2019 ProVir. All rights reserved.
//

import Foundation

public enum NetworkTaskState: Hashable, CaseIterable {
    case inProgress
    case success
    case failure
    case canceled
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
    public let storageDependency: NetworkStorageDependency?

    public var state: NetworkTaskState { return mutex.synchronized { self.unsafeState } }
    public var canceledReason: NetworkRequestCanceledReason? { return mutex.synchronized { self.unsafeCanceledReason } }

    public func cancel() {
        if state == .inProgress {
            setState(.canceled, canceledReason: .user, finishTask: false)
            workData?.cancelHandler(true, .user)
        }
    }

    init(request: NetworkBaseRequest, key: NetworkBaseRequestKey?, storageDependency: NetworkStorageDependency?) {
        self.request = request
        self.key = key
        self.storageDependency = storageDependency
    }

    private let mutex = PThreadMutexLock()
    private var unsafeState: NetworkTaskState = .inProgress
    private var unsafeCanceledReason: NetworkRequestCanceledReason?
    private var unsafeWorkData: WorkData?
    private var unsafeFinished: Bool = false
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
    private var unsafeState: NetworkTaskState = .inProgress
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

            if state != .inProgress && finishTask {
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
