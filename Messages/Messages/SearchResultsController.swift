//
//  SearchResultsController.swift
//  NetworkObjectsUI
//
//  Created by Alsey Coleman Miller on 6/15/15.
//  Copyright (c) 2015 ColemanCDA. All rights reserved.
//

import Foundation
import SwiftFoundation
import CoreData
import CoreModel
import NetworkObjects

/// Executes a search request on the server and delegates the results, merges with local cache to the delegate for display in the UI. Does not support sections.
final public class SearchResultsController: NSObject, NSFetchedResultsControllerDelegate {
    
    // MARK: - Properties
    
    /// The fetch request this controller will execute.
    public let fetchRequest: CoreModel.FetchRequest
    
    /// Client that execute the seach request.
    public let client: NetworkObjects.ClientType
    
    /// Store that will cache the seach request.
    public let store: CoreDataStore
    
    /// Sort descriptors that are additionally applied to the search results.
    public let localSortDescriptors: [NSSortDescriptor]?
    
    /// The timeout for the requests
    public var timeout: TimeInterval = 30
    
    /// The search controller's delegate.
    public weak var delegate: SearchResultsControllerDelegate?
    
    /// The cached search results.
    public private(set) var searchResults = [NSManagedObject]()
    
    // MARK: - Private Properties
    
    /// Internal fetched results controller.
    private let fetchedResultsController: NSFetchedResultsController
    
    private let originalFetchRequest: NSFetchRequest
    
    private let requestQueue: NSOperationQueue = {
       
        let queue = NSOperationQueue()
        
        queue.name = "SearchResultsController Request Queue"
        
        return queue
    }()
    
    // MARK: - Initialization
    
    public init?(fetchRequest: FetchRequest, client: NetworkObjects.ClientType, store: CoreDataStore, localSortDescriptors: [NSSortDescriptor]? = nil, delegate: SearchResultsControllerDelegate? = nil) {
        
        self.fetchRequest = fetchRequest
        self.client = client
        self.store = store
        self.localSortDescriptors = localSortDescriptors
        self.delegate = delegate
        
        guard let searchRequest = try? NSFetchRequest(fetchRequest: fetchRequest, store: store) else {
            
            self.fetchedResultsController = NSFetchedResultsController()
            self.originalFetchRequest = NSFetchRequest()
            super.init()
            return nil
        }
        
        self.originalFetchRequest = searchRequest.copy() as! NSFetchRequest
        
        // add additional sort descriptors
        if let additionalSortDescriptors = self.localSortDescriptors {
            
            var sortDescriptors = additionalSortDescriptors
            
            sortDescriptors += searchRequest.sortDescriptors!
            
            searchRequest.sortDescriptors = sortDescriptors
        }
        
        // create new fetched results controller
        
        self.fetchedResultsController = NSFetchedResultsController(fetchRequest: searchRequest, managedObjectContext: self.store.managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        
        super.init()
        
        self.fetchedResultsController.delegate = self
    }
    
    // MARK: - Methods
    
    /// Fetches search results from server. 
    /// Must call 'loadCache()' to register for delegate notifications regarding changes to the cache.
    @IBAction public func performSearch(sender: AnyObject?) {
        
        guard let entities = self.store.managedObjectContext.persistentStoreCoordinator?.managedObjectModel.entitiesByName,
            let entity: NSEntityDescription = {
                
                for (entityName, entity) in entities {
                    
                    if entityName == self.fetchRequest.entityName { return entity }
                }
                
                return nil
            }() else { fatalError("Entity \(self.fetchRequest.entityName) not found on managed object model") }
        
        self.requestQueue.addOperationWithBlock { [weak self] () -> Void in
            
            guard let controller = self else { return }
            
            var results: [Resource]
            
            var managedObjects = [NSManagedObject]()
            
            do {
                results = try controller.client.search(controller.fetchRequest)
                
                let resourceIDs = results.map({ (resource) -> String in resource.resourceID })
                
                try controller.store.cacheResponse(Response.Search(resourceIDs), forRequest: Request.Search(controller.fetchRequest))
                
                for resource in results {
                    
                    let objectID = try controller.store.findEntity(entity, withResourceID: resource.resourceID)!
                    
                    let managedObject = controller.store.managedObjectContext.objectWithID(objectID)
                    
                    managedObjects.append(managedObject)
                }
            }
            
            catch {
                
                controller.store.managedObjectContext.performBlockAndWait({ () -> Void in
                    
                    controller.delegate?.controller(controller, didPerformSearchWithError: error)
                })
                
                return
            }
            
            controller.searchResults = managedObjects
            
            controller.delegate?.controller(controller, didPerformSearchWithError: nil)
        }
    }
    
    /// Loads caches objects. Does not fetch from server.
    /// Call this to recieve delegate notificationes about changes in the cache.
    public func loadCache() throws {
        
        try self.fetchedResultsController.performFetch()
    }
    
    /** Fetches the managed object at the specified index path from the data source. */
    public func objectAtIndex(index: UInt) -> NSManagedObject {
        
        return self.searchResults[Int(index)]
    }
    
    // MARK: - NSFetchedResultsControllerDelegate
    
    public func controllerWillChangeContent(controller: NSFetchedResultsController) {
        
        self.delegate?.controllerWillChangeContent(self)
    }
    
    public func controller(controller: NSFetchedResultsController,
        didChangeObject object: AnyObject,
        atIndexPath indexPath: NSIndexPath?,
        forChangeType type: NSFetchedResultsChangeType,
        newIndexPath: NSIndexPath?) {
            
            let managedObject = object as! NSManagedObject
            
            switch type {
                
            case .Insert:
                
                // already inserted
                if (self.searchResults as NSArray).containsObject(managedObject) {
                    
                    return
                }
                
                self.searchResults.append(managedObject)
                
                self.searchResults = (self.searchResults as NSArray).sortedArrayUsingDescriptors(self.originalFetchRequest.sortDescriptors!) as! [NSManagedObject]
                
                let row = (self.searchResults as NSArray).indexOfObject(managedObject)
                
                self.delegate?.controller(self, didInsertManagedObject: managedObject, atIndex: UInt(row))
                
            case .Update:
                
                let row = (self.searchResults as NSArray).indexOfObject(managedObject)
                
                self.delegate?.controller(self, didUpdateManagedObject: managedObject, atIndex: UInt(row))
                
            case .Move:
                
                // get old row
                
                let oldRow = (self.searchResults as NSArray).indexOfObject(managedObject)
                
                self.searchResults = (self.searchResults as NSArray).sortedArrayUsingDescriptors(self.originalFetchRequest.sortDescriptors!) as! [NSManagedObject]
                
                let newRow = (self.searchResults as NSArray).indexOfObject(managedObject)
                
                if newRow != oldRow {
                    
                    self.delegate?.controller(self, didMoveManagedObject: managedObject, atIndex: UInt(oldRow), toIndex: UInt(newRow))
                }
                
            case .Delete:
                
                // already deleted
                if !(self.searchResults as NSArray).containsObject(managedObject) {
                    
                    return
                }
                
                let row = (self.searchResults as NSArray).indexOfObject(managedObject)
                
                self.searchResults.removeAtIndex(row)
                
                self.delegate?.controller(self, didDeleteManagedObject: managedObject, atIndex: UInt(row))
            }
    }
    
    public func controllerDidChangeContent(controller: NSFetchedResultsController) {
        
        self.delegate?.controllerDidChangeContent(self)
    }
}

// MARK: - Protocol

/* Delegate methods for the search controller. */
public protocol SearchResultsControllerDelegate: class {
    
    /// Informs the delegate that a search request has completed with the specified error (if any).
    func controller(controller: SearchResultsController, didPerformSearchWithError error: ErrorType?)
    
    func controllerWillChangeContent(controller: SearchResultsController)
    
    func controllerDidChangeContent(controller: SearchResultsController)
    
    func controller(controller: SearchResultsController, didInsertManagedObject managedObject: NSManagedObject, atIndex index: UInt)
    
    func controller(controller: SearchResultsController, didDeleteManagedObject managedObject: NSManagedObject, atIndex index: UInt)
    
    func controller(controller: SearchResultsController, didUpdateManagedObject managedObject: NSManagedObject, atIndex index: UInt)
    
    func controller(controller: SearchResultsController, didMoveManagedObject managedObject: NSManagedObject, atIndex oldIndex: UInt, toIndex newIndex: UInt)
}

