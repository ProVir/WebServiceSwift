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
    case error
    case canceled
    case duplicate
}

public enum StorageDependency {
    case notDepend
    case dependSuccessResult
    case dependFull
    case dependManual(Set<RequestState>)

    func needCancel(requestState state: RequestState) -> Bool {
        switch self {
        case .notDepend: return false
        case .dependSuccessResult: return state == .success
        case .dependFull: return state != .inProgress && state != .error
        case .dependManual(let list): return list.contains(state)
        }
    }
}

public final class RequestTask {
    public let request: WebServiceBaseRequesting
    public let key: AnyHashable?
    public let storageTask: StorageTask?
    public let storageDependency: StorageDependency

    public var state: RequestState { return mutex.synchronized { self.unsafeState } }

    public func cancel() {
        if state == .inProgress {
            setState(.canceled, finishTask: false)
            workData?.cancelHandler(true)
        }
    }

    init(request: WebServiceBaseRequesting, key: AnyHashable?, storageTask: StorageTask?, storageDependency: StorageDependency) {
        self.request = request
        self.key = key
        self.storageTask = storageTask
        self.storageDependency = storageDependency
    }

    private let mutex = PThreadMutexLock()
    private var unsafeState: RequestState = .inProgress
    private var unsafeWorkData: WorkData?
    private var unsafeFinished: Bool = false
}

public final class StorageTask {
    public enum CanceledReason {
        case user
        case storage
        case request(RequestState)
    }

    public let request: WebServiceBaseRequesting

    public var state: RequestState { return mutex.synchronized { self.unsafeState } }
    public var canceledReason: CanceledReason? { return mutex.synchronized { self.unsafeCanceledReason } }

    public func cancel() {
        mutex.synchronized {
            self.unsafeState = .canceled
            self.unsafeCanceledReason = .user
        }
    }

    init(request: WebServiceBaseRequesting) {
        self.request = request
    }

    private let mutex = PThreadMutexLock()
    private var unsafeState: RequestState = .inProgress
    private var unsafeCanceledReason: CanceledReason?
}

// MARK: Internal
extension RequestTask {
    struct WorkData {
        let requestId: UInt64
        let gatewayIndex: Int
        let cancelHandler: (_ neededInGatewayCancel: Bool) -> Void
    }

    var workData: WorkData? {
        get { return mutex.synchronized { self.unsafeWorkData } }
        set { mutex.synchronized { self.unsafeWorkData = newValue } }
    }

    var isFinished: Bool {
        return mutex.synchronized { unsafeFinished }
    }

    func setState(_ state: RequestState, finishTask: Bool) {
        mutex.synchronized {
            self.unsafeState = state
            if state != .inProgress && finishTask {
                self.unsafeFinished = true
                self.unsafeWorkData = nil
            }
        }

        if storageDependency.needCancel(requestState: state) {
            storageTask?.cancelFromRequest(state: state)
        }
    }
}

extension StorageTask {
    var isCanceled: Bool {
        return mutex.synchronized { unsafeState == .canceled || unsafeState == .duplicate }
    }

    func setStateFromStorage(_ state: RequestState) {
        mutex.synchronized {
            self.unsafeState = state
            if state == .canceled || state == .duplicate {
                self.unsafeCanceledReason = .storage
            }
        }
    }

    func cancelFromRequest(state: RequestState) {
        mutex.synchronized {
            self.unsafeState = (state == .duplicate ? .duplicate : .canceled)
            self.unsafeCanceledReason = .request(state)
        }
    }
}
