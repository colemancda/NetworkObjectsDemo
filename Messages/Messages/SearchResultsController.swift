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
final public class SearchResultsController<Client: ClientType, ManagedObject: NSManagedObject> {
    
    // MARK: - Properties
    
    /// The fetch request this controller will execute.
    public let fetchRequest: CoreModel.FetchRequest
    
    /// Client that will execute and cache the seach request.
    public let store: NetworkObjects.Store<Client, CoreDataStore>
    
    /// The managed object context that that will be used to fetch the results.
    ///
    /// - Note: The delegate's methods will be called on this context's queue.
    public let managedObjectContext: NSManagedObjectContext
    
    /// Sort descriptors that are additionally applied to the search results.
    public let localSortDescriptors: [NSSortDescriptor]?
    
    /// The search controller's delegate.
    public var event = SearchResultsControllerEvent()
    
    /// The cached search results.
    public private(set) var searchResults: [ManagedObject] = []
    
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
    
    public init(fetchRequest: FetchRequest, store: NetworkObjects.Store<Client, CoreDataStore>, managedObjectContext: NSManagedObjectContext? = nil, localSortDescriptors: [NSSortDescriptor]? = nil) throws {
        
        self.fetchRequest = fetchRequest
        self.store = store
        self.localSortDescriptors = localSortDescriptors
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
    
    public func dataAtIndex(index: Int) -> SearchResultData<ManagedObject> {
        
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
        
        let data: SearchResultData<ManagedObject>
        
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
                        
                        var requestError: ErrorType?
                        
                        do { try controller.store.get(resource) }
                            
                        catch { requestError = error }
                        
                        // make sure the table view hasnt been refreshed at a later date.
                        guard dateRefreshed == controller.dateRefreshed &&
                            searchResults == controller.searchResults
                            else { return }
                        
                        // configure cell for error
                        controller.managedObjectContext.performBlock {
                            
                            controller.event.willChangeContent()
                            
                            controller.event.didUpdate(index: index, error: requestError)
                            
                            controller.event.didChangeContent()
                        }
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
            
            var managedObjects: [ManagedObject] = []
            
            do {
                results = try controller.store.search(controller.fetchRequest)
                
                for resource in results {
                    
                    let objectID = try controller.store.cacheStore.findEntity(entity, withResourceID: resource.resourceID)!
                    
                    let managedObject = controller.managedObjectContext.objectWithID(objectID) as! ManagedObject
                    
                    managedObjects.append(managedObject)
                }
            }
            
            catch {
                
                controller.managedObjectContext.performBlock({ () -> Void in
                    
                    controller.event.didPerformSearch(error: error)
                })
                
                return
            }
            
            controller.managedObjectContext.performBlockAndWait({ () -> Void in
                
                let previousSearchResultsArray = controller.searchResults as NSArray
                
                controller.event.willChangeContent()
                
                for (index, searchResult) in managedObjects.enumerate() {
                    
                    // already present
                    if previousSearchResultsArray.containsObject(searchResult) {
                        
                        let previousIndex = previousSearchResultsArray.indexOfObject(searchResult) as Int
                        
                        // move cell
                        if index != previousIndex {
                            
                            controller.event.didMove(index: previousIndex, newIndex: index)
                        }
                            
                            // update cell
                        else {
                            
                            controller.event.didUpdate(index: index, error: nil)
                        }
                    }
                        
                        // new managed object
                    else {
                        
                        controller.event.didInsert(index: index)
                    }
                }
                
                controller.searchResults = managedObjects
                
                controller.event.didChangeContent()
                
                controller.event.didPerformSearch(error: nil)
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
        
        self.event.willChangeContent()
    }
    
    func controller(controller: NSFetchedResultsController,
        didChangeObject managedObject: NSManagedObject,
        atIndexPath indexPath: NSIndexPath?,
        forChangeType type: NSFetchedResultsChangeType,
        newIndexPath: NSIndexPath?) {
            
            let genericManagedObject = managedObject as! ManagedObject
            
            switch type {
                
            case .Insert:
                
                // already inserted
                if (self.searchResults as NSArray).containsObject(managedObject) {
                    
                    return
                }
                
                self.searchResults.append(genericManagedObject)
                
                self.searchResults = (self.searchResults as NSArray).sortedArrayUsingDescriptors(self.originalFetchRequest.sortDescriptors!) as! [ManagedObject]
                
                let row = (self.searchResults as NSArray).indexOfObject(managedObject)
                
                self.event.didInsert(index: row)
                
            case .Update:
                
                let row = (self.searchResults as NSArray).indexOfObject(managedObject)
                
                self.event.didUpdate(index: row, error: nil)
                
            case .Move:
                
                // get old row
                
                let oldRow = (self.searchResults as NSArray).indexOfObject(managedObject)
                
                self.searchResults = (self.searchResults as NSArray).sortedArrayUsingDescriptors(self.originalFetchRequest.sortDescriptors!) as! [ManagedObject]
                
                let newRow = (self.searchResults as NSArray).indexOfObject(managedObject)
                
                if newRow != oldRow {
                    
                    self.event.didMove(index: oldRow, newIndex: newRow)
                }
                
            case .Delete:
                
                // already deleted
                if !(self.searchResults as NSArray).containsObject(managedObject) {
                    
                    return
                }
                
                let row = (self.searchResults as NSArray).indexOfObject(managedObject)
                
                self.searchResults.removeAtIndex(row)
                
                self.event.didDelete(index: row)
            }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        
        self.event.didChangeContent()
    }
}

// MARK: - Protocol

public struct SearchResultsControllerEvent {
    
    // Request Callback
    
    /// Informs the delegate that a search request has completed with the specified error (if any).
    public var didPerformSearch: ((error: ErrorType?) -> ()) = { (error) in }
    
    // Change Notification Callbacks
    
    public var willChangeContent: (() -> ()) = { }
    
    public var didChangeContent: (() -> ()) = { }
    
    public var didInsert: ((index: Int) -> ()) = { (index) in }
    
    public var didDelete: ((index: Int) -> ()) = { (index) in }
    
    public var didUpdate: ((index: Int, error: ErrorType?) -> ()) = { (index, error) in }
    
    public var didMove: ((index: Int, newIndex: Int) -> ()) = { (index, newIndex) in }
    
    private init() { }
}




