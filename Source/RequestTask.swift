//
//  NetworkRequestTask.swift
//  WebServiceSwift
//
//  Created by Vitalii Korotkii on 22/11/2019.
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
}

// MARK: - Internal
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

private extension NetworkRequestTask {
    func unsafePrepareForPerform() -> ((NetworkRequestTask) -> Void)? {
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

    func unsafeRestoreToRepeat() {
        self.unsafeCanceledReason = nil
        self.unsafeWorkData = nil
        self.unsafeFinished = false
    }
}
