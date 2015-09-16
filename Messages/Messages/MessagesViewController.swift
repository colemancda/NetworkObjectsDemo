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
            
            managedObjectModel.addResourceIDAttribute(CoreMessages.ResourceIDAttributeName)
            
            managedObjectModel.addDateCachedAttribute(CoreMessages.DateCachedAttributeName)
            
            let cacheStore = CoreDataStore(model: model, managedObjectContext: context, resourceIDAttributeName: CoreMessages.ResourceIDAttributeName)!
            
            let sort = CoreModel.SortDescriptor(propertyName: Message.Attribute.Date.rawValue, ascending: false)
            
            let fetchRequest = FetchRequest(entityName: Message.EntityName, sortDescriptors: [sort])
            
            let store = NetworkObjects.Store(client: client, cacheStore: cacheStore, dateCachedAttributeName: CoreMessages.DateCachedAttributeName)
            
            self.searchResultsController = try! SearchResultsController(fetchRequest: fetchRequest, store: store)
        }
    }
    
    // MARK: - Actions
    
    @IBAction func create(sender: AnyObject) {
        
        
    }
    
    // MARK: - Methods
    
    override func dequeueReusableCellForIndexPath(indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = self.tableView.dequeueReusableCellWithIdentifier(MessageCell.Identifier, forIndexPath: indexPath)
        
        return cell
    }
    
    override func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath, withError error: ErrorType? = nil) {
        
        if error != nil {
            
            cell.textLabel!.text = NSLocalizedString("Error: ", comment: "Error: ") + "\(error!)"
            
            return
        }
        
        // get model object
        let managedObject = self.objectAtIndexPath(indexPath)
        
        let resourceID = managedObject.valueForKey(CoreMessages.ResourceIDAttributeName) as! String
        
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

