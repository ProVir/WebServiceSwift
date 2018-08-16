//
//  WebServiceDataBaseStorage.swift
//  WebServiceSwift 3.0.0
//
//  Created by Короткий Виталий (ViR) on 21.07.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation
import CoreData

/// Base protocol for requests support WebServiceDataBaseStorage.
public protocol WebServiceRequestDataBaseStoring: WebServiceRequestBaseStoring {
    
    /// Unique identificator for read and write data if current request support storage.
    var identificatorForDataBaseStorage: String? { get }
}

/// Conform to protocol if requests support WebServiceDataBaseStorage and store raw data in data base.
public protocol WebServiceRequestRawDataBaseStoring: WebServiceRequestDataBaseStoring { }

/// Conform to protocol if requests support WebServiceDataBaseStorage and store value data in data base.
public protocol WebServiceRequestAnyValueDataBaseStoring: WebServiceRequestDataBaseStoring {
    
    /**
     Coding data from custom type to binary data.
     
     - Parameter value: Data with type from response.
     - Results: Binary data after coding if supported.
     */
    func writeAnyDataToDataBaseStorage(value: Any) -> Data?
    
    /**
     Decoding data from binary data to custom type.
     
     - Parameter data: Binary data from disk.
     - Results: Custom type after decoding if supported.
     */
    func readAnyDataFromDataBaseStorage(data: Data) throws -> Any?
}

/// Conform to protocol if requests support WebServiceDataBaseStorage and store data in data base.
public protocol WebServiceRequestValueDataBaseStoring: WebServiceRequestAnyValueDataBaseStoring, WebServiceRequesting {
    /**
     Coding data from custom type to binary data.
     
     - Parameter value: Data with type from response.
     - Results: Binary data after coding if supported.
     */
    func writeDataToDataBaseStorage(value: ResultType) -> Data?
    
    /**
     Decoding data from binary data to custom type.
     
     - Parameter data: Binary data from disk.
     - Results: Custom type after decoding if supported.
     */
    func readDataFromDataBaseStorage(data: Data) throws -> ResultType?
}


public extension WebServiceRequestValueDataBaseStoring {
    func writeAnyDataToDataBaseStorage(value: Any) -> Data? {
        if let value = value as? ResultType {
            return writeDataToDataBaseStorage(value: value)
        } else {
            return nil
        }
    }
    
    func readAnyDataFromDataBaseStorage(data: Data) throws -> Any? {
        return try readDataFromDataBaseStorage(data: data)
    }
}


/// Simple store in sqlite data base (CoreData) for WebService.
public class WebServiceDataBaseStorage: WebServiceStorage {
    typealias Item = WebServiceDataBaseStorage_Item
    
    public let supportDataClassification: Set<AnyHashable>
    
    private let managedObjectContext: NSManagedObjectContext
    
    // MARK: Constructor
    public init?(sqliteFileUrl: URL? = nil, supportDataClassification: Set<AnyHashable> = []) {
        self.supportDataClassification = supportDataClassification
        
        //Setup CoreData
        //1. NSManagedObjectModel
        guard let modelUrl = Bundle(for: WebServiceDataBaseStorage.self).url(forResource: "WebServiceDataBaseStorage", withExtension: "momd"),
            let managedObjectModel = NSManagedObjectModel(contentsOf: modelUrl) else { return nil }
        
        let fileUrl = sqliteFileUrl
            ?? FileManager.default.urls(for: .cachesDirectory,
                                        in: .userDomainMask).first?
                .appendingPathComponent("webServiceDataBaseStorage.sqlite")
        
        //2. NSPersistentStoreCoordinator
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)

        do {
            try persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: fileUrl, options: nil)
        } catch {
            assertionFailure("Unresolved CoreData error in WebServiceDataBaseStorage: \(error)")
            return nil
        }
        
        //3.
        self.managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        self.managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator;
    }
    
    
    // MARK: WebServiceStoraging
    public func isSupportedRequest(_ request: WebServiceBaseRequesting) -> Bool {
        guard let request = request as? WebServiceRequestDataBaseStoring else {
            return false
        }
        
        if request.identificatorForDataBaseStorage != nil &&
            (request is WebServiceRequestRawDataBaseStoring || request is WebServiceRequestAnyValueDataBaseStoring) {
            return true
        } else {
            return false
        }
    }
    
    public func readData(request: WebServiceBaseRequesting, completionHandler: @escaping (Bool, Date?, WebServiceAnyResponse) -> Void) throws {
        DispatchQueue.main.async {
            guard let request = request as? WebServiceRequestDataBaseStoring, let identificator = request.identificatorForDataBaseStorage else {
                completionHandler(false, nil, .error(WebServiceResponseError.notFoundData))
                return
            }
            
            guard let item = self.findStoreData(identificator: identificator), let binary = item.binary else {
                completionHandler(false, nil, .error(WebServiceResponseError.notFoundData))
                return
            }
            
            //Read Item from CoreData
            var timeStamp = item.timeStamp
            if timeStamp?.timeIntervalSinceNow ?? -0.1 > 0 {
                timeStamp = nil
            }
            
            if item.isRaw {
                //Readed RAW data - use if supported request
                if request is WebServiceRequestRawDataBaseStoring {
                    completionHandler(true, timeStamp, .data(binary))
                } else {
                    completionHandler(true, nil, .error(WebServiceResponseError.notFoundData))
                }
                
            } else if let request = request as? WebServiceRequestAnyValueDataBaseStoring {
                //Readed value and can decode
                do {
                    if let data = try request.readAnyDataFromDataBaseStorage(data: binary) {
                        completionHandler(false, timeStamp, .data(data))
                    } else {
                        completionHandler(false, nil, .error(WebServiceResponseError.notFoundData))
                    }
                } catch {
                    completionHandler(false, nil, .error(error))
                }
                
            } else {
                //Value don't supported request
                completionHandler(false, nil, .error(WebServiceResponseError.notFoundData))
            }
        }
    }
    
    public func writeData(request: WebServiceBaseRequesting, data: Any, isRaw: Bool) {
        guard let identificator = (request as? WebServiceRequestDataBaseStoring)?.identificatorForDataBaseStorage else {
            return
        }
        
        let binary: Data
        
        //Custom
        if let request = request as? WebServiceRequestAnyValueDataBaseStoring {
            if !isRaw, let binaryData = request.writeAnyDataToDataBaseStorage(value: data) {
                binary = binaryData
            } else {
                return
            }
        }
            
        //Raw
        else if isRaw, request is WebServiceRequestRawDataBaseStoring {
            if let data = data as? Data {
                binary = data
            } else if let binaryData = (data as? WebServiceRawDataSource)?.binaryRawData {
                binary = binaryData
            } else {
                return
            }
        }
            
        //Unknow
        else { return }
        
        //Save in CoreData
        DispatchQueue.main.async {
            let item = self.findStoreData(identificator: identificator) ?? {
                let entityDescription = NSEntityDescription.entity(forEntityName: "Item", in: self.managedObjectContext)!
                let item = Item(entity: entityDescription, insertInto: self.managedObjectContext)
                item.idItem = identificator
                return item
                }()
            
            item.isRaw = isRaw
            item.binary = binary
            item.timeStamp = Date()
            
            self.saveContext()
        }
    }
    
    public func deleteData(request: WebServiceBaseRequesting) {
        guard let identificator = (request as? WebServiceRequestDataBaseStoring)?.identificatorForDataBaseStorage else {
            return
        }
        
        let handler =  {
            if let item = self.findStoreData(identificator: identificator) {
                self.managedObjectContext.delete(item)
                self.saveContext()
            }
        }
        
        if Thread.isMainThread {
            handler()
        } else {
            DispatchQueue.main.async(execute: handler)
        }
    }
    
    public func deleteAllData() {
        let handler = {
            let fetchRequest: NSFetchRequest<Item> = Item.fetchRequest()
            if let results = try? self.managedObjectContext.fetch(fetchRequest) {
                for item in results {
                    self.managedObjectContext.delete(item)
                }
                
                self.saveContext()
            }
        }
        
        if Thread.isMainThread {
            handler()
        } else {
            DispatchQueue.main.async(execute: handler)
        }
    }
    
    
    //MARK: - Private
    private func saveContext() {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                assertionFailure("Unresolved CoreData error in WebServiceDataBaseStorage: \(error)")
            }
        }
    }
    
    private func findStoreData(identificator: String) -> Item? {
        let fetchRequest: NSFetchRequest<Item> = Item.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", "idItem", identificator)
        fetchRequest.fetchLimit = 1
        
        return (try? managedObjectContext.fetch(fetchRequest))?.first
    }

}

