//
//  Gateway.swift
//  WebServiceSwift 4.0.0
//
//  Created by Короткий Виталий (ViR) on 16/07/2019.
//  Copyright © 2017 - 2019 ProVir. All rights reserved.
//

import Foundation

/// Protocol for gateway
public protocol NetworkGateway: class {
    /// Thread Dispatch Queue for `perofrmRequest()` and `cancelRequests()` methods.
    var queueForRequest: DispatchQueue? { get }

    /// Thread Dispatch Queue for `dataProcessingFromStorage()` method with raw data from storage.
    var queueForDataProcessingFromStorage: DispatchQueue? { get }

    /// When `true`, showed networkActivityIndicator in statusBar when requests in process.
    var useNetworkActivityIndicator: Bool { get }

    /**
     Asks whether the request supports this gateway.

     If `rawDataTypeForRestoreFromStorage != nil`, after this method called `dataProcessingFromStorage(request:rawData:)` method.

     - Parameters:
     - request: Request for test.
     - forDataProcessingFromStorage: If no nil - request restore raw data from storage with data.
     - Returns: If request support this gateway - return true.
     */
    func isSupportedRequest(_ request: NetworkBaseRequest, forDataProcessingFromStorage rawDataType: NetworkStorageRawData.Type?) -> Bool

    /**
     Perform request to server. Need call `completionWithRawData` and only one.

     If `queueForRequest != nil`, thread use from `queueForRequest`, else default thread (usually main).

     - Parameters:
     - requestId: Unique id for request. ID generated always unique for all Gateways and WebServices. Use for `canceledRequest()`.
     - request: Original request with data.
     - completionWithRawData: Result with raw data from server or error. RawData usually binary data and this data saved as rawData in storage.
     */
    func performRequest(requestId: NetworkRequestId, request: NetworkBaseRequest, completion: @escaping (Result<NetworkGatewayResponse, Error>) -> Void)

    /**
     Preformed after canceled request.

     If `queueForRequest != nil`, thread use from `queueForRequest`, else default thread (usually main).

     - Parameter requestId: Id for canceled.
     */
    func canceledRequest(requestId: NetworkRequestId)

    /**
     Process raw data from storage.
     Used `queueForDataProcessingFromStorage` if != nil.

     - Parameters:
     - request: Original request.
     - rawData: Raw data from storage, usually binary Data.

     - Throws: Error proccess data from storage to result.
     - Returns: Result data.
     */
    func dataProcessingFromStorage(request: NetworkBaseRequest, rawData: NetworkStorageRawData) throws -> Any
}

#if os(iOS)
#else
extension NetworkGateway {
    var useNetworkActivityIndicator: Bool { return false }
}
#endif
