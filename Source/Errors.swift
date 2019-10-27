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
 - `invalidTypeResponse`: Invalid result type from gateway
 - `unknown`: Unknown error in gateway
 */
public enum NetworkError: Error {
    case notFoundGateway
    case notSupportRequest
    case invalidTypeResponse(Any.Type, require: Any.Type)
    case unknown
}

/**
 Storage errors

 - `noFoundStorage`: If storage not found in `[storages]` for request
 - `noFoundGateway`: If gateway not found in `[gateways]` for data processing readed raw data
 - `notFoundData`: Data not found in storage
 - `failureFetch`: Error fetch in storage
 - `failureDataProcessing`: Error data processing readed raw data in gateway
 - `invalidTypeResponse`: Invalid result type from storage or gateway
 */
public enum NetworkStorageError: Error {
    case notFoundStorage
    case notFoundGateway
    case notFoundData
    case failureFetch(Error)
    case failureDataProcessing(Error)
    case invalidTypeResponse(Any.Type, require: Any.Type)
}
