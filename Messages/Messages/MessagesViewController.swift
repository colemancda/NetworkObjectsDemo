//
//  MessagesViewController.swift
//  Messages
//
//  Created by Alsey Coleman Miller on 9/13/15.
//  Copyright © 2015 ColemanCDA. All rights reserved.
//

import UIKit
import SwiftFoundation
import NetworkObjects
import CoreModel
import CoreData
import CoreMessages

class MessagesViewController: FetchedResultsViewController {
    
    // MARK: - Properties
    
    var serverURL: String! {
        
        didSet {
            
            let managedObjectModel = CoreMessages.ManagedObjectModel()
            
            let model = managedObjectModel.toModel()!
            
            let client = Client.HTTP(serverURL: serverURL, model: model, HTTPClient: HTTP.Client())
            
            managedObjectModel.addResourceIDAttribute(CoreMessages.ResourceIDAttributeName)
            
            let context = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
            
            context.undoManager = nil
            
            context.persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
            
            try! context.persistentStoreCoordinator!.addPersistentStoreWithType(NSInMemoryStoreType, configuration: nil, URL: nil, options: nil)
            
            let store = CoreDataStore(model: model, managedObjectContext: context, resourceIDAttributeName: CoreMessages.ResourceIDAttributeName)!
            
            let sort = CoreModel.SortDescriptor(propertyName: "date", ascending: false)
            
            let fetchRequest = FetchRequest(entityName: "Message", sortDescriptors: [sort])
            
            client.cacheStores = [store]
            
            self.searchResultsController = SearchResultsController(fetchRequest: fetchRequest, client: client, store: store)
        }
    }
    
    // MARK: - Actions
    
    @IBAction func create(sender: AnyObject) {
        
        
    }
    
    // MARK: - Methods
    
    /// Subclasses should overrride this to provide custom cells.
    override func dequeueReusableCellForIndexPath(indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = self.tableView.dequeueReusableCellWithIdentifier(MessageCell.Identifier, forIndexPath: indexPath)
        
        return cell
    }
    
    /// Subclasses should override this to configure custom cells.
    override func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath, withError error: ErrorType? = nil) {
        
        if error != nil {
            
            cell.textLabel!.text = NSLocalizedString("Error: ", comment: "Error: ") + "\(error!)"
            
            return
        }
        
        // get model object
        let managedObject = self.objectAtIndexPath(indexPath)
        
        let resourceIDAttributeName = self.searchResultsController.store.resourceIDAttributeName
        
        let resourceID = managedObject.valueForKey(resourceIDAttributeName) as! String
        
        // get date cached
        let dateCached = self.datesCached[resourceID]
        
        // configure empty cell...
        if dateCached == nil {
            
            cell.textLabel?.text = NSLocalizedString("Loading...", comment: "Loading...")
            
            cell.detailTextLabel?.text = ""
            
            cell.userInteractionEnabled = false
            
            return
        }
        
        // configure cell...
        cell.userInteractionEnabled = true
        
        // Entity name + resource ID
        cell.textLabel!.text = "\(managedObject.entity)" + "\(managedObject.valueForKey(self.searchResultsController.store.resourceIDAttributeName))"
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        // show edit panel
    }
}

// MARK: - Supporting Classes

class MessageCell: UITableViewCell {
    
    static var Identifier: String { return "MessageCell" }
    
    @IBOutlet weak var messageTextLabel: UILabel!
    
    @IBOutlet weak var dateTextLabel: UILabel!
    
}

