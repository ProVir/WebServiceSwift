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
    typealias Item = WebServiceDataBaseStorageItem
    
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
        self.managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
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
    
    public func fetch(request: WebServiceBaseRequesting, completionHandler: @escaping (Date?, WebServiceStorageResponse) -> Void) {
        guard let request = request as? WebServiceRequestDataBaseStoring, let identificator = request.identificatorForDataBaseStorage else {
            completionHandler(nil, .error(WebServiceResponseError.notFoundData))
            return
        }
        
        managedObjectContext.perform {
            guard let item = self.findStoreData(identificator: identificator), let binary = item.binary else {
                completionHandler(nil, .error(WebServiceResponseError.notFoundData))
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
                    completionHandler(timeStamp, .rawData(binary))
                } else {
                    completionHandler(nil, .error(WebServiceResponseError.notFoundData))
                }
                
            } else if let request = request as? WebServiceRequestAnyValueDataBaseStoring {
                //Readed value and can decode
                do {
                    if let data = try request.readAnyDataFromDataBaseStorage(data: binary) {
                        completionHandler(timeStamp, .value(data))
                    } else {
                        completionHandler(nil, .error(WebServiceResponseError.notFoundData))
                    }
                } catch {
                    completionHandler(nil, .error(error))
                }
                
            } else {
                //Value don't supported request
                completionHandler(nil, .error(WebServiceResponseError.notFoundData))
            }
        }
    }

    public func save(request: WebServiceBaseRequesting, rawData: WebServiceStorageRawData?, value: Any) {
        guard let identificator = (request as? WebServiceRequestDataBaseStoring)?.identificatorForDataBaseStorage else {
            return
        }

        let binary: Data
        let isRaw: Bool

        //Value
        if let request = request as? WebServiceRequestAnyValueDataBaseStoring,
           let binaryData = request.writeAnyDataToDataBaseStorage(value: value) {
            binary = binaryData
            isRaw = false
        }

        //Raw
        else if request is WebServiceRequestRawDataBaseStoring,
           let binaryData = rawData as? Data {
            binary = binaryData
            isRaw = true
        }

        //Unknow
        else { return }

        //Save in CoreData
        managedObjectContext.perform {
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
    
    public func delete(request: WebServiceBaseRequesting) {
        guard let identificator = (request as? WebServiceRequestDataBaseStoring)?.identificatorForDataBaseStorage else {
            return
        }
        
        managedObjectContext.perform {
            if let item = self.findStoreData(identificator: identificator) {
                self.managedObjectContext.delete(item)
                self.saveContext()
            }
        }
    }
    
    public func deleteAll() {
        managedObjectContext.perform {
            let fetchRequest: NSFetchRequest<Item> = Item.fetchRequest()
            if let results = try? self.managedObjectContext.fetch(fetchRequest) {
                for item in results {
                    self.managedObjectContext.delete(item)
                }
                
                self.saveContext()
            }
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

@objc(WebServiceDataBaseStorageItem)
public class WebServiceDataBaseStorageItem: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WebServiceDataBaseStorageItem> {
        return NSFetchRequest<WebServiceDataBaseStorageItem>(entityName: "Item")
    }

    @NSManaged public var binary: Data?
    @NSManaged public var idItem: String?
    @NSManaged public var isRaw: Bool
    @NSManaged public var timeStamp: Date?
}
