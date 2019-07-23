//
//  WebServiceDataBaseStorage.swift
//  WebServiceSwift 4.0.0
//
//  Created by Короткий Виталий (ViR) on 21.07.2018.
//  Copyright © 2018 ProVir. All rights reserved.
//

import Foundation
import CoreData

/// Simple store in sqlite data base (CoreData) for WebService.
public class WebServiceDataBaseStorage: WebServiceStorage {
    typealias Item = WebServiceDataBaseStorageItem
    
    public let supportDataClassification: Set<AnyHashable>?
    private let managedObjectContext: NSManagedObjectContext
    
    // MARK: Constructor
    public init?(sqliteFileUrl: URL? = nil, supportDataClassification: Set<AnyHashable>? = nil) {
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
        guard let request = request as? WebServiceRequestEasyStoring else {
            return false
        }

        return request.identificatorForStorage != nil
    }
    
    public func fetch(request: WebServiceBaseRequesting, completionHandler: @escaping (WebServiceStorageResponse) -> Void) {
        guard let request = request as? WebServiceRequestEasyStoring, let identificator = request.identificatorForStorage else {
            completionHandler(.error(WebServiceResponseError.notFoundData))
            return
        }

        managedObjectContext.perform {
            guard let item = self.findStoreData(identificator: identificator), let binary = item.binary else {
                completionHandler(.error(WebServiceResponseError.notFoundData))
                return
            }
            
            //Read Item from CoreData
            var timeStamp = item.timeStamp
            if timeStamp?.timeIntervalSinceNow ?? -0.1 > 0 {
                timeStamp = nil
            }
            
            if item.isRaw {
                completionHandler(.rawData(binary, timeStamp))
                
            } else if let request = request as? WebServiceRequestBinaryValueBaseStoring {
                //Readed value and can decode
                do {
                    if let data = try request.decodeToAnyValueFromStorage(binary: binary) {
                        completionHandler(.value(data, timeStamp))
                    } else {
                        completionHandler(.error(WebServiceResponseError.notFoundData))
                    }
                } catch {
                    completionHandler(.error(error))
                }
            } else {
                //Value don't supported request
                completionHandler(.error(WebServiceResponseError.notFoundData))
            }
        }
    }

    public func save(request: WebServiceBaseRequesting, rawData: WebServiceStorageRawData?, value: Any) {
        guard let identificator = (request as? WebServiceRequestEasyStoring)?.identificatorForStorage else {
            return
        }

        let binary: Data
        let isRaw: Bool
        let timeStamp = Date()

        if let request = request as? WebServiceRequestBinaryValueBaseStoring,
           let binaryData = request.encodeToBinaryForStorage(anyValue: value) {
            binary = binaryData
            isRaw = true

        } else if let binaryData = rawData as? Data {
            binary = binaryData
            isRaw = true

        } else {
            return
        }

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
            item.timeStamp = timeStamp

            self.saveContext()
        }
    }
    
    public func delete(request: WebServiceBaseRequesting) {
        guard let identificator = (request as? WebServiceRequestEasyStoring)?.identificatorForStorage else {
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
