//
//  NetworkPerfomer.swift
//  WebServiceSwift
//
//  Created by Vitalii Korotkii on 20/09/2019.
//  Copyright © 2019 ProVir. All rights reserved.
//

import Foundation

public protocol NetworkPerfomer {
    init(session: NetworkSession)
}

public final class NetworkPerfomerFactory {
    private enum Source {
        case session(NetworkSession)
        case configuration(NetworkSessionConfiguration)
    }

    private class Transaction {
        private let config: NetworkSessionConfiguration
        private(set) lazy var session: NetworkSession = .init(config)

        init(_ config: NetworkSessionConfiguration) {
            self.config = config
        }
    }

    private let source: Source
    private var transactions: [Transaction] = []

    public init(session: NetworkSession) {
        source = .session(session)
    }

    public init(configuration: NetworkSessionConfiguration) {
        source = .configuration(configuration)
    }

    public func beginTransaction() {
        switch source {
        case .configuration(let config):
            transactions.append(.init(config))

        case .session: break
        }
    }

    public func endTransaction() {
        guard transactions.isEmpty == false else { return }
        transactions.removeLast()
    }

    public func performInTransaction(_ handler: () -> Void) {
        beginTransaction()
        handler()
        endTransaction()
    }

    public func make<T: NetworkPerfomer>(_ type: T.Type = T.self, useTransaction: Bool = true) -> T {
        if useTransaction, let transaction = transactions.last {
            return T.init(session: transaction.session)
        } else {
            switch source {
            case .session(let session): return T.init(session: session)
            case .configuration(let config): return T.init(session: .init(config))
            }
        }
    }
}
