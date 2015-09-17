//
//  FetchedResultsViewController.swift
//  NetworkObjectsUI
//
//  Created by Alsey Coleman Miller on 12/10/14.
//  Copyright (c) 2014 ColemanCDA. All rights reserved.
//

import Foundation
import SwiftFoundation
import UIKit
import CoreData
import CoreModel
import NetworkObjects

public protocol SearchResultsTableViewController: SearchResultsControllerDelegate, UITableViewDataSource {
    
    typealias Client: ClientType
    typealias ManagedObject: NSManagedObject
    typealias TableViewCell: UITableViewCell
    
    var searchResultsController: SearchResultsController<Client, ManagedObject> { get }
    
    var tableView: UITableView { get }
    
    var refreshControl: UIRefreshControl? { get }
    
    func dequeueReusableCellForIndex(index: Int) -> TableViewCell
    
    func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath, withError error: ErrorType? = nil)
}

/// Fetches instances of an entity on the server and displays them in a table view. 
///
/// - Note: Supports single section only.
public class FetchedResultsViewController: UITableViewController, SearchResultsControllerDelegate {
    
    // MARK: - Properties
    
    final public var searchResultsController: SearchResultsController!
    
    /// Date the last search request was made.
    final public private(set) var dateRefreshed: Date?
    
    /// Resource IDs mapped to the dates they were last fetched from the server.
    final public private(set) var datesCached = [String: Date]()
    
    // MARK: - Private Properties
    
    private var previousSearchResults: [NSManagedObject]?
    
    private let requestQueue: NSOperationQueue = {
        
        let queue = NSOperationQueue()
        
        queue.name = "FetchedResultsViewController Request Queue"
        
        return queue
        }()
    
    // MARK: - Initialization
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // load from server
        self.refresh(self)
    }
    
    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // start reloading data before view appears
        self.refresh(self)
    }
    
    // MARK: - Methods
    
    /// Fetches the managed object at the specified index path from the data source.
    final public func objectAtIndexPath(indexPath: NSIndexPath) -> NSManagedObject {
        
        assert(indexPath.section == 0, "Only single section supported")
        
        return self.searchResultsController!.objectAtIndex(UInt(indexPath.row))
    }
    
    /// Subclasses should overrride this to provide custom cells.
    public func dequeueReusableCellForIndexPath(indexPath: NSIndexPath) -> UITableViewCell {
        
        let CellIdentifier = NSStringFromClass(UITableViewCell)
        
        let cell = self.tableView.dequeueReusableCellWithIdentifier(CellIdentifier, forIndexPath: indexPath)
        
        return cell
    }
    
    /// Subclasses should override this to configure custom cells.
    public func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath, withError error: ErrorType? = nil) {
        
        if error != nil {
            
            cell.textLabel!.text = NSLocalizedString("Error: ", comment: "Error: ") + "\(error!)"
            
            return
        }
        
        // get model object
        let managedObject = self.objectAtIndexPath(indexPath)
        
        // not cached
        if self.dateRefreshed == nil {
            
            // configure empty cell...
            
            cell.textLabel?.text = NSLocalizedString("Loading...", comment: "Loading...")
            
            cell.detailTextLabel?.text = ""
            
            cell.userInteractionEnabled = false
            
            return
        }
        
        // configure cell...
        
        cell.userInteractionEnabled = true
        
        // Entity name + resource ID
        cell.textLabel!.text = "\(managedObject.entity)" + "\(managedObject.valueForKey(self.searchResultsController.store.cacheStore.resourceIDAttributeName))"
    }
    
    // MARK: - Actions
    
    @IBAction final public func refresh(sender: AnyObject) {
        
        self.dateRefreshed = Date()
        
        self.previousSearchResults = self.searchResultsController!.searchResults
        
        self.searchResultsController!.performSearch(sender)
    }
    
    // MARK: - Private Methods
    
    private func deleteManagedObject(managedObject: NSManagedObject) {
        
        let resourceIDAttributeName = self.searchResultsController.store.cacheStore.resourceIDAttributeName
        
        let entityName = managedObject.entity.name!
        
        let resourceID = managedObject.valueForKey(resourceIDAttributeName) as! String
        
        let resource = Resource(entityName, resourceID)
        
        self.requestQueue.addOperationWithBlock { () in
            
            do { try self.searchResultsController.store.delete(resource) }
            
            catch {
                
                NSOperationQueue.mainQueue().addOperationWithBlock({ () in
                    
                    self.showErrorAlert("\(error)", retryHandler: { () in
                        
                        self.deleteManagedObject(managedObject)
                    })
                })
            }
        }
    }
    
    // MARK: - UITableViewDataSource
    
    final public override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        
        return 1
    }
    
    final public override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        let count = self.searchResultsController?.searchResults.count
        
        return count ?? 0
    }
    
    final public override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = self.dequeueReusableCellForIndexPath(indexPath) as UITableViewCell
        
        // configure cell
        self.configureCell(cell, atIndexPath: indexPath)
        
        // fetch from server... (loading table view after -refresh:)
        if let dateRefreshed = self.dateRefreshed {
            
            // get model object
            let managedObject = self.objectAtIndexPath(indexPath)
            
            let resourceIDAttributeName = self.searchResultsController.store.cacheStore.resourceIDAttributeName
            
            let resourceID = managedObject.valueForKey(resourceIDAttributeName) as! String
            
            // get date cached
            let dateCached = self.datesCached[resourceID]
            
            // fetch if older than refresh date or not fetched yet
            if dateCached == nil || dateCached < dateRefreshed {
                
                self.requestQueue.addOperationWithBlock({ [weak self] () -> Void in
                    
                    guard let controller = self else { return }
                    
                    let resource = Resource(managedObject.entity.name!, resourceID)
                    
                    do { try controller.searchResultsController.store.get(resource) }
                    
                    catch {
                        
                        /* TODO
                        // configure cell for error
                        NSOperationQueue.mainQueue().addOperationWithBlock({ [weak self] () -> Void in
                            
                            guard let controller = self else { return }
                            
                            let newIndexPath = tableView.indexPathForCell(cell)
                            
                            guard newIndexPath == indexPath else { return }
                            
                            controller.configureCell(cell, atIndexPath: indexPath, withError: error)
                        })
                        */
                    }
                    
                    // fetched results controller should update cell...
                    
                    NSOperationQueue.mainQueue().addOperationWithBlock({ [weak self] () -> Void in
                        
                        guard let controller = self else { return }
                        
                        controller.datesCached[resourceID] = Date()
                    })
                })
            }
        }
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    public override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        
        // get model object
        let managedObject = self.objectAtIndexPath(indexPath)
        
        switch editingStyle {
            
        case .Delete:
            
            self.deleteManagedObject(managedObject)
            
        default:
            
            return
        }
    }
    
    public override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
}
