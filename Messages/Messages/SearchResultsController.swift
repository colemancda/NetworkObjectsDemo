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
    
    /// Sort descriptors that are additionally applied to the search results.
    public let localSortDescriptors: [NSSortDescriptor]?
    
    /// The search controller's delegate.
    public weak var delegate: SearchResultsControllerDelegate?
    
    /// The cached search results.
    public private(set) var searchResults = [ManagedObject]()
    
    /// Date the last search request was made.
    public private(set) var dateRefreshed: Date?
    
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
    
    public init(fetchRequest: FetchRequest, store: NetworkObjects.Store<Client, CoreDataStore>, localSortDescriptors: [NSSortDescriptor]? = nil, delegate: SearchResultsControllerDelegate? = nil) throws {
        
        self.fetchRequest = fetchRequest
        self.store = store
        self.localSortDescriptors = localSortDescriptors
        self.delegate = delegate
        
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
        self.fetchedResultsController = NSFetchedResultsController(fetchRequest: searchRequest, managedObjectContext: self.store.cacheStore.managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        
        self.fetchedResultsController.delegate = self.fetchedResultsControllerDelegate
        
        try self.fetchedResultsController.performFetch()
    }
    
    // MARK: - Methods
    
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
            
            var managedObjects = [ManagedObject]()
            
            do {
                results = try controller.store.search(controller.fetchRequest)
                
                for resource in results {
                    
                    let objectID = try controller.store.cacheStore.findEntity(entity, withResourceID: resource.resourceID)!
                    
                    let managedObject = controller.store.cacheStore.managedObjectContext.objectWithID(objectID) as! ManagedObject
                    
                    managedObjects.append(managedObject)
                }
            }
            
            catch {
                
                controller.store.cacheStore.managedObjectContext.performBlockAndWait({ () -> Void in
                    
                    controller.delegate?.controller(controller, didPerformSearchWithError: error)
                })
                
                return
            }
            
            controller.store.cacheStore.managedObjectContext.performBlockAndWait({ () -> Void in
                
                controller.searchResults = managedObjects
                
                controller.delegate?.controller(controller, didPerformSearchWithError: nil)
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
        
        self.delegate?.controllerWillChangeContent(self)
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
                
                self.delegate?.controller(self, didInsertManagedObject: genericManagedObject, atIndex: row)
                
            case .Update:
                
                let row = (self.searchResults as NSArray).indexOfObject(managedObject)
                
                self.delegate?.controller(self, didUpdateManagedObject: genericManagedObject, atIndex: row)
                
            case .Move:
                
                // get old row
                
                let oldRow = (self.searchResults as NSArray).indexOfObject(managedObject)
                
                self.searchResults = (self.searchResults as NSArray).sortedArrayUsingDescriptors(self.originalFetchRequest.sortDescriptors!) as! [ManagedObject]
                
                let newRow = (self.searchResults as NSArray).indexOfObject(managedObject)
                
                if newRow != oldRow {
                    
                    self.delegate?.controller(self, didMoveManagedObject: genericManagedObject, atIndex: oldRow, toIndex: newRow)
                }
                
            case .Delete:
                
                // already deleted
                if !(self.searchResults as NSArray).containsObject(managedObject) {
                    
                    return
                }
                
                let row = (self.searchResults as NSArray).indexOfObject(managedObject)
                
                self.searchResults.removeAtIndex(row)
                
                self.delegate?.controller(self, didDeleteManagedObject: genericManagedObject, atIndex: row)
            }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        
        self.delegate?.controllerDidChangeContent(self)
    }
}

// MARK: - Protocol

/// Delegate methods for the search controller.
public protocol SearchResultsControllerDelegate: class {
    
    // Request Callback
    
    /// Informs the delegate that a search request has completed with the specified error (if any).
    func controller<Client: ClientType, ManagedObject: NSManagedObject>(controller: SearchResultsController<Client, ManagedObject>, didPerformSearchWithError error: ErrorType?)
    
    // Notification Callbacks
    
    func controllerWillChangeContent<Client: ClientType, ManagedObject: NSManagedObject>(controller: SearchResultsController<Client, ManagedObject>)
    
    func controllerDidChangeContent<Client: ClientType, ManagedObject: NSManagedObject>(controller: SearchResultsController<Client, ManagedObject>)
    
    func controller<Client: ClientType, ManagedObject: NSManagedObject>(controller: SearchResultsController<Client, ManagedObject>, didInsertManagedObject managedObject: ManagedObject, atIndex index: Int)
    
    func controller<Client: ClientType, ManagedObject: NSManagedObject>(controller: SearchResultsController<Client, ManagedObject>, didDeleteManagedObject managedObject: ManagedObject, atIndex index: Int)
    
    func controller<Client: ClientType, ManagedObject: NSManagedObject>(controller: SearchResultsController<Client, ManagedObject>, didUpdateManagedObject managedObject: ManagedObject, atIndex index: Int)
    
    func controller<Client: ClientType, ManagedObject: NSManagedObject>(controller: SearchResultsController<Client, ManagedObject>, didMoveManagedObject managedObject: ManagedObject, atIndex oldIndex: Int, toIndex newIndex: Int)
}

// MARK: - Protocol Implementation

extension SearchResultsControllerDelegate where Self: UITableViewController {
    
    public func controller<Client: ClientType, ManagedObject: NSManagedObject>(controller: SearchResultsController<Client, ManagedObject>, didPerformSearchWithError error: ErrorType?) {
        
        self.refreshControl?.endRefreshing()
        
        // show error
        if let searchError = error {
            
            let text: String
            
            if searchError.dynamicType == NSError.self {
                
                text = (searchError as NSError).localizedDescription
            }
            else {
                
                text = "\(searchError)"
            }
            
            self.showErrorAlert(text, retryHandler: nil)
            
            return
        }
    }
    
    public func controllerWillChangeContent<Client: ClientType, ManagedObject: NSManagedObject>(controller: SearchResultsController<Client, ManagedObject>) {
        self.tableView.beginUpdates()
    }
    
    public func controllerDidChangeContent<Client: ClientType, ManagedObject: NSManagedObject>(controller: SearchResultsController<Client, ManagedObject>) {
        
        self.tableView.endUpdates()
    }
    
    public func controller<Client: ClientType, ManagedObject: NSManagedObject>(controller: SearchResultsController<Client, ManagedObject>, didInsertManagedObject managedObject: ManagedObject, atIndex index: Int) {
        
        self.tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: index, inSection: 0)], withRowAnimation: .Automatic)
    }
    
    public func controller<Client: ClientType, ManagedObject: NSManagedObject>(controller: SearchResultsController<Client, ManagedObject>, didDeleteManagedObject managedObject: ManagedObject, atIndex index: Int) {
        
        self.tableView.deleteRowsAtIndexPaths([NSIndexPath(forRow: index, inSection: 0)], withRowAnimation: .Automatic)
    }
    
    /*
    public func controller<Client: ClientType, ManagedObject: NSManagedObject>(controller: SearchResultsController<Client, ManagedObject>, didUpdateManagedObject managedObject: ManagedObject, atIndex index: Int) {
        
        let indexPath = NSIndexPath(forRow: index, inSection: 0)
        
        if let cell = self.tableView.cellForRowAtIndexPath(indexPath) {
            
            self.configureCell(cell, atIndexPath: indexPath)
        }
    }
    */
    
    func controller<Client: ClientType, ManagedObject: NSManagedObject>(controller: SearchResultsController<Client, ManagedObject>, didMoveManagedObject managedObject: ManagedObject, atIndex newIndex: Int, toIndex oldIndex: Int) {
        
        self.tableView.deleteRowsAtIndexPaths([NSIndexPath(forRow: newIndex, inSection: 0)], withRowAnimation: .Automatic)
        
        self.tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: oldIndex, inSection: 0)], withRowAnimation: .Automatic)
    }
}




