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
import UIKit

/// Data results the ```SearchResultsController``` fetches and caches.
public enum SearchResultData<ManagedObject: NSManagedObject> {
    
    /// The search result is not cached. (ResourceID is embedded)
    case NotCached(String)
    
    /// The search result was fetched and is cached.
    case Cached(ManagedObject)
}

/// Executes a search request on the server and delegates the results,
/// merges with local cache to the delegate for display in the UI. 
///
/// - Note: Does not support sections.
///
final public class SearchResultsController<Delegate: SearchResultsControllerDelegate> {
    
    // MARK: - Properties
    
    /// The fetch request this controller will execute.
    public let fetchRequest: CoreModel.FetchRequest
    
    /// Client that will execute and cache the seach request.
    public let store: NetworkObjects.Store<Delegate.Client, CoreDataStore>
    
    /// The managed object context that that will be used to fetch the results.
    ///
    /// - Note: The delegate's methods will be called on this context's queue.
    public let managedObjectContext: NSManagedObjectContext
    
    /// Sort descriptors that are additionally applied to the search results.
    public let localSortDescriptors: [NSSortDescriptor]?
    
    /// The search controller's delegate.
    public weak var delegate: Delegate?
    
    /// The cached search results.
    public private(set) var searchResults: [Delegate.ManagedObject] = []
    
    /// Date the last search request was made.
    public private(set) var dateRefreshed: Date?
    
    /// Whether the ```SearchResultsController``` should notify its delegate of changes in the managed object context.
    ///
    /// Default value is ```false```. By default the ```SearchResultsController``` will only notify its delegate when a search request completes. 
    ///
    public var notifyChanges: Bool = false {
        
        didSet {
            
            if notifyChanges == true {
                
                do { try self.fetchedResultsController.performFetch() }
                
                catch { fatalError("Could not fetch from managed object context. \(error)") }
            }
        }
    }
    
    // MARK: - Private Properties
    
    /// Internal fetched results controller.
    private let fetchedResultsController: NSFetchedResultsController!
    
    private let originalFetchRequest: NSFetchRequest!
    
    private let requestQueue: NSOperationQueue = {
       
        let queue = NSOperationQueue()
        
        queue.name = "SearchResultsController Request Queue"
        
        return queue
    }()
    
    private lazy var fetchedResultsControllerDelegate: FetchedResultsControllerDelegateWrapper = FetchedResultsControllerDelegateWrapper(delegate: self)
    
    // MARK: - Initialization
    
    public init(fetchRequest: FetchRequest, store: NetworkObjects.Store<Delegate.Client, CoreDataStore>, delegate: Delegate, managedObjectContext: NSManagedObjectContext? = nil, localSortDescriptors: [NSSortDescriptor]? = nil) throws {
        
        self.fetchRequest = fetchRequest
        self.store = store
        self.localSortDescriptors = localSortDescriptors
        self.delegate = delegate
        self.managedObjectContext = managedObjectContext ?? store.cacheStore.managedObjectContext
        
        guard self.store.dateCachedAttributeName != nil else {
            
            fatalError("Provided Store must have a dateCachedAttributeName value")
        }
        
        var searchRequest: NSFetchRequest!
        
        do { searchRequest = try NSFetchRequest(fetchRequest: fetchRequest, store: store.cacheStore) }
        
        catch {
            
            self.originalFetchRequest = nil
            self.fetchedResultsController = nil
            
            throw error
        }
        
        self.originalFetchRequest = searchRequest.copy() as! NSFetchRequest
        
        // add additional sort descriptors
        if let additionalSortDescriptors = self.localSortDescriptors {
            
            var sortDescriptors = additionalSortDescriptors
            
            sortDescriptors += searchRequest.sortDescriptors!
            
            searchRequest.sortDescriptors = sortDescriptors
        }
        
        // create new fetched results controller
        self.fetchedResultsController = NSFetchedResultsController(fetchRequest: searchRequest, managedObjectContext: self.managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        
        self.fetchedResultsController.delegate = self.fetchedResultsControllerDelegate
    }
    
    // MARK: - Methods
    
    public func dataAtIndex(index: Int) -> SearchResultData<Delegate.ManagedObject> {
        
        let searchResults = self.searchResults
        
        let managedObject = searchResults[index]
        
        let resourceIDAttributeName = self.store.cacheStore.resourceIDAttributeName
        
        let dateCachedAttributeName = self.store.dateCachedAttributeName!
        
        let resourceID = (managedObject as NSManagedObject).valueForKey(resourceIDAttributeName) as! String
        
        let dateCached: Date?
        
        if let date = (managedObject as NSManagedObject).valueForKey(dateCachedAttributeName) as? NSDate {
            
            dateCached = Date(foundation: date)
        }
        else { dateCached = nil }
        
        let data: SearchResultData<Delegate.ManagedObject>
        
        if dateCached == nil {
            
            data = .NotCached(resourceID)
        }
        else {
            
            data = .Cached(managedObject)
        }
        
        // fetch from server... (loading table view after -performSearch:)
        do {
            
            if let dateRefreshed = self.dateRefreshed {
                
                // fetch if older than refresh date or not fetched yet
                if dateCached == nil || dateCached < dateRefreshed {
                    
                    self.requestQueue.addOperationWithBlock({ [weak self] () -> Void in
                        
                        guard let controller = self else { return }
                        
                        let resource = Resource(managedObject.entity.name!, resourceID)
                        
                        do { try controller.store.get(resource) }
                            
                        catch {
                            
                            // make sure the table view hasnt been refreshed at a later date.
                            guard dateRefreshed == controller.dateRefreshed &&
                                searchResults == controller.searchResults
                                else { return }
                            
                            // configure cell for error
                            controller.managedObjectContext.performBlock {
                                
                                controller.delegate?.controllerWillChangeContent(controller as! Delegate.Controller)
                                
                                controller.delegate?.controller(controller as! Delegate.Controller, didUpdateManagedObject: managedObject, atIndex: index, withError: error)
                                
                                controller.delegate?.controllerDidChangeContent(controller as! Delegate.Controller)
                            }
                        }
                        
                        // fetched results controller should update cell...
                    })
                }
            }
        }
        
        return data
    }
    
    /// Fetches search results from server.
    @IBAction public func performSearch(sender: AnyObject?) {
        
        self.dateRefreshed = Date()
        
        guard let entities = self.store.cacheStore.managedObjectContext.persistentStoreCoordinator?.managedObjectModel.entitiesByName,
            let entity: NSEntityDescription = {
                
                for (entityName, entity) in entities {
                    
                    if entityName == self.fetchRequest.entityName { return entity }
                }
                
                return nil
            }() else { fatalError("Entity \(self.fetchRequest.entityName) not found on managed object model") }
        
        self.requestQueue.addOperationWithBlock { [weak self] () -> Void in
            
            guard let controller = self else { return }
            
            var results: [Resource]
            
            var managedObjects: [Delegate.ManagedObject] = []
            
            do {
                results = try controller.store.search(controller.fetchRequest)
                
                for resource in results {
                    
                    let objectID = try controller.store.cacheStore.findEntity(entity, withResourceID: resource.resourceID)!
                    
                    let managedObject = controller.managedObjectContext.objectWithID(objectID) as! Delegate.ManagedObject
                    
                    managedObjects.append(managedObject)
                }
            }
            
            catch {
                
                controller.managedObjectContext.performBlockAndWait({ () -> Void in
                    
                    controller.delegate?.controller(controller as! Delegate.Controller, didPerformSearchWithError: error)
                })
                
                return
            }
            
            controller.managedObjectContext.performBlockAndWait({ () -> Void in
                
                controller.searchResults = managedObjects
                
                controller.delegate?.controller(controller as! Delegate.Controller, didPerformSearchWithError: nil)
            })
        }
    }
}

// MARK: - Private

/// Swift wrapper for ```NSFetchedResultsControllerDelegate```.
@objc private final class FetchedResultsControllerDelegateWrapper: NSObject, NSFetchedResultsControllerDelegate {
    
    private weak var delegate: InternalFetchedResultsControllerDelegate!
    
    private init(delegate: InternalFetchedResultsControllerDelegate) {
        
        self.delegate = delegate
    }
    
    @objc private func controllerWillChangeContent(controller: NSFetchedResultsController) {
        
        self.delegate.controllerWillChangeContent(controller)
    }
    
    @objc private func controllerDidChangeContent(controller: NSFetchedResultsController) {
        
        self.delegate.controllerDidChangeContent(controller)
    }
    
    @objc private func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        
        let managedObject = anObject as! NSManagedObject
        
        self.delegate.controller(controller, didChangeObject: managedObject, atIndexPath: indexPath, forChangeType: type, newIndexPath: newIndexPath)
    }
}

private protocol InternalFetchedResultsControllerDelegate: class {
    
    func controller(controller: NSFetchedResultsController, didChangeObject managedObject: NSManagedObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?)
    
    func controllerWillChangeContent(controller: NSFetchedResultsController)
    
    func controllerDidChangeContent(controller: NSFetchedResultsController)
}

extension SearchResultsController: InternalFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        
        self.delegate?.controllerWillChangeContent(self as! Delegate.Controller)
    }
    
    func controller(controller: NSFetchedResultsController,
        didChangeObject managedObject: NSManagedObject,
        atIndexPath indexPath: NSIndexPath?,
        forChangeType type: NSFetchedResultsChangeType,
        newIndexPath: NSIndexPath?) {
            
            let genericManagedObject = managedObject as! Delegate.ManagedObject
            
            switch type {
                
            case .Insert:
                
                // already inserted
                if (self.searchResults as NSArray).containsObject(managedObject) {
                    
                    return
                }
                
                self.searchResults.append(genericManagedObject)
                
                self.searchResults = (self.searchResults as NSArray).sortedArrayUsingDescriptors(self.originalFetchRequest.sortDescriptors!) as! [Delegate.ManagedObject]
                
                let row = (self.searchResults as NSArray).indexOfObject(managedObject)
                
                self.delegate?.controller(self as! Delegate.Controller, didInsertManagedObject: genericManagedObject, atIndex: row)
                
            case .Update:
                
                let row = (self.searchResults as NSArray).indexOfObject(managedObject)
                
                self.delegate?.controller(self as! Delegate.Controller, didUpdateManagedObject: genericManagedObject, atIndex: row, withError: nil)
                
            case .Move:
                
                // get old row
                
                let oldRow = (self.searchResults as NSArray).indexOfObject(managedObject)
                
                self.searchResults = (self.searchResults as NSArray).sortedArrayUsingDescriptors(self.originalFetchRequest.sortDescriptors!) as! [Delegate.ManagedObject]
                
                let newRow = (self.searchResults as NSArray).indexOfObject(managedObject)
                
                if newRow != oldRow {
                    
                    self.delegate?.controller(self as! Delegate.Controller, didMoveManagedObject: genericManagedObject, atIndex: oldRow, toIndex: newRow)
                }
                
            case .Delete:
                
                // already deleted
                if !(self.searchResults as NSArray).containsObject(managedObject) {
                    
                    return
                }
                
                let row = (self.searchResults as NSArray).indexOfObject(managedObject)
                
                self.searchResults.removeAtIndex(row)
                
                self.delegate?.controller(self as! Delegate.Controller, didDeleteManagedObject: genericManagedObject, atIndex: row)
            }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        
        self.delegate?.controllerDidChangeContent(self as! Delegate.Controller)
    }
}

// MARK: - Protocol

/// Delegate methods for the search controller.
public protocol SearchResultsControllerDelegate: class {
    
    typealias Controller = SearchResultsController<Self>
    typealias Client: ClientType
    typealias ManagedObject: NSManagedObject
    
    var client: Client { get }
    
    // Request Callback
    
    /// Informs the delegate that a search request has completed with the specified error (if any).
    func controller(controller: Controller, didPerformSearchWithError error: ErrorType?)
    
    // Notification Callbacks
    
    func controllerWillChangeContent(controller: Controller)
    
    func controllerDidChangeContent(controller: Controller)
    
    func controller(controller: Controller, didInsertManagedObject managedObject: ManagedObject, atIndex index: Int)
    
    func controller(controller: Controller, didDeleteManagedObject managedObject: ManagedObject, atIndex index: Int)
    
    func controller(controller: Controller, didUpdateManagedObject managedObject: ManagedObject, atIndex index: Int, withError error: ErrorType?)
    
    func controller(controller: Controller, didMoveManagedObject managedObject: ManagedObject, atIndex oldIndex: Int, toIndex newIndex: Int)
}




