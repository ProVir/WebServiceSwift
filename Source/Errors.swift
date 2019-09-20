//
//  Errors.swift
//  WebServiceSwift
//
//  Created by Vitalii Korotkii on 20/09/2019.
//  Copyright © 2019 ProVir. All rights reserved.
//

import Foundation

/**
 General errors

 - `noFoundGateway`: If gateway not found in `[gateways]` for request
 - `notSupportRequest`: If request after test fot gateway contains invalid query or etc
 - `invalidTypeResult`: Invalid result type from gateway
 - `notFoundDataInStorage`: Data not found in storage
 - `unknown`: Unknown error in gateway
 */
public enum NetworkError: Error {
    case notFoundGateway
    case notSupportRequest
    case invalidTypeResult(Any.Type, require: Any.Type)
    case notFoundDataInStorage
    case unknown
}

/**
 Storage errors

 - `noFoundStorage`: If storage not found in `[storages]` for request
 - `noFoundGateway`: If gateway not found in `[gateways]` for data processing readed raw data
 - `failureFetch`: Error fetch in storage
 - `failureDataProcessing`: Error data processing readed raw data in gateway
 - `invalidTypeResult`: Invalid result type from storage or gateway
 */
public enum NetworkStorageError: Error {
    case notFoundStorage
    case notFoundGateway
    case failureFetch(Error)
    case failureDataProcessing(Error)
    case invalidTypeResult(Any.Type, require: Any.Type)
}
