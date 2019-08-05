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
        mutex.synchronized { self.handler = handler }
    }

    // MARK: Internal
    func addRequest(_ requestId: UInt64) {
        mutex.synchronized { listRequestId.insert(requestId) }
    }

    func removeRequest(_ requestId: UInt64) {
        mutex.synchronized { listRequestId.remove(requestId) }
    }

    func removeRequests(_ requestListIds: Set<UInt64>) {
        mutex.synchronized { listRequestId.subtract(requestListIds) }
    }

    // MARK: Private
    private let mutex = PThreadMutexLock()

    private var listRequestId = Set<UInt64>() {
        didSet { self.isVisible = listRequestId.isEmpty == false }
    }

    private var handler: (Bool) -> Void = { isVisible in
        // Default implementation
        #if os(iOS)
        UIApplication.shared.isNetworkActivityIndicatorVisible = isVisible
        #endif
    }
}
