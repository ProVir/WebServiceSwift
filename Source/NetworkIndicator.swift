//
//  NetworkActivityIndicatorHandler.swift
//  WebServiceSwift 4.0.0
//
//  Created by Vitalii Korotkii on 05/08/2019.
//  Copyright © 2019 ProVir. All rights reserved.
//

#if os(iOS)
import UIKit
#else
import Foundation
#endif

public final class NetworkActivityIndicatorHandler {
    public static let shared = NetworkActivityIndicatorHandler()

    public private(set) var isVisible: Bool = false {
        didSet {
            if oldValue != isVisible {
                DispatchQueue.main.async { [handler, isVisible] in handler(isVisible) }
            }
        }
    }

    public func setHandler(_ handler: @escaping (_ isVisible: Bool) -> Void) {
        lock.sync { self.handler = handler }
    }

    // MARK: Internal
    func addRequest(_ requestId: NetworkRequestId) {
        lock.sync { listRequestId.insert(requestId) }
    }

    func removeRequest(_ requestId: NetworkRequestId) {
        lock.sync { listRequestId.remove(requestId) }
    }

    func removeRequests(_ requestListIds: Set<NetworkRequestId>) {
        lock.sync { listRequestId.subtract(requestListIds) }
    }

    // MARK: Private
    private let lock = DispatchQueueLock(label: "ru.provir.soneta.NetworkActivityIndicatorHandler", concurrentRead: false)

    private var listRequestId = Set<NetworkRequestId>() {
        didSet { self.isVisible = listRequestId.isEmpty == false }
    }

    private var handler: (Bool) -> Void = { isVisible in
        // Default implementation
        #if os(iOS)
        UIApplication.shared.isNetworkActivityIndicatorVisible = isVisible
        #endif
    }
}
