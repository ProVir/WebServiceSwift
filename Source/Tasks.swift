//
//  Tasks.swift
//  WebServiceSwift 4.0.0
//
//  Created by Vitalii Korotkii on 15/08/2019.
//  Copyright © 2019 ProVir. All rights reserved.
//

import Foundation

public enum RequestState: Hashable, CaseIterable {
    case inProgress
    case success
    case failure
    case canceled
}

public enum StorageDependency {
    case notDepend
    case dependSuccessResult
    case dependFull
    case dependManual(Set<RequestState>)

    func shouldCancel(requestState state: RequestState) -> Bool {
        switch self {
        case .notDepend: return false
        case .dependSuccessResult: return state == .success
        case .dependFull: return state != .inProgress && state != .failure
        case .dependManual(let list): return list.contains(state)
        }
    }
}

public final class RequestTask {
    public let request: BaseRequest
    public let key: AnyHashable?
    public let storageTask: StorageTask?
    public let storageDependency: StorageDependency

    public var state: RequestState { return mutex.synchronized { self.unsafeState } }
    public var canceledReason: RequestCanceledReason? { return mutex.synchronized { self.unsafeCanceledReason } }

    public func cancel() {
        if state == .inProgress {
            setState(.canceled, canceledReason: .user, finishTask: false)
            workData?.cancelHandler(true, .user)
        }
    }

    init(request: BaseRequest, key: AnyHashable?, storageTask: StorageTask?, storageDependency: StorageDependency) {
        self.request = request
        self.key = key
        self.storageTask = storageTask
        self.storageDependency = storageDependency
    }

    private let mutex = PThreadMutexLock()
    private var unsafeState: RequestState = .inProgress
    private var unsafeCanceledReason: RequestCanceledReason?
    private var unsafeWorkData: WorkData?
    private var unsafeFinished: Bool = false
}

public final class StorageTask {
    public enum CanceledReason {
        case user
        case request(RequestState, RequestCanceledReason?)
    }

    public let request: BaseRequest

    public var state: RequestState { return mutex.synchronized { self.unsafeState } }
    public var canceledReason: CanceledReason? { return mutex.synchronized { self.unsafeCanceledReason } }

    public func cancel() {
        mutex.synchronized {
            self.unsafeState = .canceled
            self.unsafeCanceledReason = .user
        }
    }

    init(request: BaseRequest) {
        self.request = request
    }

    private let mutex = PThreadMutexLock()
    private var unsafeState: RequestState = .inProgress
    private var unsafeCanceledReason: CanceledReason?
}

// MARK: - Internal
extension RequestTask {
    struct WorkData {
        let requestId: UInt64
        let gatewayIndex: Int
        let cancelHandler: (_ neededInGatewayCancel: Bool, RequestCanceledReason) -> Void
    }

    var workData: WorkData? {
        get { return mutex.synchronized { self.unsafeWorkData } }
        set { mutex.synchronized { self.unsafeWorkData = newValue } }
    }

    var isFinished: Bool {
        return mutex.synchronized { unsafeFinished }
    }

    func setState(_ state: RequestState, canceledReason: RequestCanceledReason?, finishTask: Bool) {
        mutex.synchronized {
            self.unsafeState = state
            self.unsafeCanceledReason = canceledReason

            if state != .inProgress && finishTask {
                self.unsafeFinished = true
                self.unsafeWorkData = nil
            }
        }

        if storageDependency.shouldCancel(requestState: state) {
            storageTask?.cancelFromRequest(reason: canceledReason)
        }
    }
}

extension StorageTask {
    var isCanceled: Bool {
        return mutex.synchronized { unsafeState == .canceled }
    }

    var requestCanceledReason: RequestCanceledReason {
        switch canceledReason {
        case .request(_, let reason): return reason ?? .unknown
        default: return .unknown
        }
    }

    func setStateFromStorage(_ state: RequestState) {
        mutex.synchronized {
            self.unsafeState = state
        }
    }

    func cancelFromRequest(reason: RequestCanceledReason?) {
        mutex.synchronized {
            self.unsafeState = .canceled
            self.unsafeCanceledReason = .request(state, reason)
        }
    }
}
