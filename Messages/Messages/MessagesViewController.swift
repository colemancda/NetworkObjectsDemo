//
//  MessagesViewController.swift
//  Messages
//
//  Created by Alsey Coleman Miller on 9/13/15.
//  Copyright © 2015 ColemanCDA. All rights reserved.
//

import UIKit
import Foundation
import SwiftFoundation
import CoreModel
import NetworkObjects
import CoreData
import CoreMessages

class MessagesViewController: UITableViewController {
    
    // MARK: - Properties
    
    var searchResultsController: SearchResultsController<Client.HTTP, CoreMessages.Message>!
    
    var serverURL: String! {
        
        didSet { self.configure() }
    }
    
    // MARK: - Private Properties
    
    private let dateFormatter = StyledDateFormatter(dateStyle: .ShortStyle, timeStyle: .ShortStyle)
    
    private let requestQueue: NSOperationQueue = {
        
        let queue = NSOperationQueue()
        
        queue.name = "MessagesViewController Request Queue"
        
        return queue
        }()
    
    // MARK: - Initialization
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //self.configure()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.refresh(self)
    }
    
    // MARK: - Actions
    
    @IBAction func refresh(sender: AnyObject) {
        
        self.searchResultsController.performSearch(self)
    }
    
    @IBAction func create(sender: AnyObject) {
        
        let alertController = UIAlertController(title: NSLocalizedString("Create", comment: "Create"),
            message: NSLocalizedString("Enter the text of the message", comment: "Enter the text of the message"),
            preferredStyle: UIAlertControllerStyle.Alert)
        
        alertController.addTextFieldWithConfigurationHandler { (textField: UITextField) -> Void in
            
            textField.placeholder = NSLocalizedString("Message Text", comment: "Message Text")
        }
        
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Create", comment: "Create"),
            style: UIAlertActionStyle.Default, handler: { (action: UIAlertAction) -> Void in
                
                let textField = alertController.textFields!.first!
                
                let text = textField.text!
                
                let values = [Message.Attribute.Text.rawValue: Value.Attribute(AttributeValue.String(text))]
                
                NSOperationQueue().addOperationWithBlock({ () -> Void in
                    
                    do { try self.searchResultsController.store.create(Message.EntityName, initialValues: values) }
                        
                    catch {
                        
                        NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                            
                            self.showErrorAlert("\(error)")
                        })
                        
                        return
                    }
                    
                    NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                        
                        
                    })
                })
        }))
        
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"),
            style: UIAlertActionStyle.Destructive, handler: { (action: UIAlertAction) -> Void in
                
                alertController.dismissViewControllerAnimated(true, completion: nil)
        }))
        
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    func configure() {
        
        let managedObjectModel = CoreMessages.ManagedObjectModel()
        
        let model = managedObjectModel.toModel()!
        
        let client = NetworkObjects.Client.HTTP(serverURL: serverURL, model: model, HTTPClient: HTTP.Client())
        
        managedObjectModel.addResourceIDAttribute(CoreMessages.ResourceIDAttributeName)
        
        managedObjectModel.addDateCachedAttribute(CoreMessages.DateCachedAttributeName)
        
        managedObjectModel.markAllPropertiesAsOptional()
        
        let context = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        
        context.undoManager = nil
        
        context.persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        
        try! context.persistentStoreCoordinator!.addPersistentStoreWithType(NSInMemoryStoreType, configuration: nil, URL: nil, options: nil)
        
        let cacheStore = CoreDataStore(model: model, managedObjectContext: context, resourceIDAttributeName: CoreMessages.ResourceIDAttributeName)!
        
        let sort = CoreModel.SortDescriptor(propertyName: Message.Attribute.Date.rawValue, ascending: false)
        
        let fetchRequest = FetchRequest(entityName: Message.EntityName, sortDescriptors: [sort])
        
        let store = NetworkObjects.Store(client: client, cacheStore: cacheStore, dateCachedAttributeName: CoreMessages.DateCachedAttributeName)
        
        self.searchResultsController = try! SearchResultsController(fetchRequest: fetchRequest, store: store)
        
        // setup events
        
        self.searchResultsController.notifyChanges = true
        
        self.searchResultsController.event.didPerformSearch = { (error) in
                        
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
        
        self.searchResultsController.event.willChangeContent = { self.tableView.beginUpdates() }
        
        self.searchResultsController.event.didChangeContent = { self.tableView.endUpdates() }
        
        self.searchResultsController.event.didInsert = { (index) in
            
            self.tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: index, inSection: 0)], withRowAnimation: .Automatic)
        }
        
        self.searchResultsController.event.didDelete = { (index) in
            
            self.tableView.deleteRowsAtIndexPaths([NSIndexPath(forRow: index, inSection: 0)], withRowAnimation: .Automatic)
        }
        
        self.searchResultsController.event.didUpdate = { (index, error) in
            
            let indexPath = NSIndexPath(forRow: index, inSection: 0)
            
            if let cell = self.tableView.cellForRowAtIndexPath(indexPath) as? MessageCell {
                
                self.configureCell(cell, atIndex: indexPath.row, error: error)
            }
        }
        
        self.searchResultsController.event.didMove = { (oldIndex, newIndex) in
            
            self.tableView.deleteRowsAtIndexPaths([NSIndexPath(forRow: newIndex, inSection: 0)], withRowAnimation: .Automatic)
            
            self.tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: oldIndex, inSection: 0)], withRowAnimation: .Automatic)
        }
    }
    
    func configureCell(cell: MessageCell, atIndex index: Int, error: ErrorType?) {
        
        guard error == nil else {
            
            cell.userInteractionEnabled = false
            
            cell.messageTextLabel.text = NSLocalizedString("Error: ", comment: "Error: ") + "\(error!)"
            
            cell.dateTextLabel.text = ""
            
            return
        }
        
        let data = self.searchResultsController.dataAtIndex(index)
        
        let message = self.searchResultsController.searchResults[index]
        
        switch data {
            
        case .NotCached(_):
            
            cell.userInteractionEnabled = false
            
            cell.messageTextLabel.text = NSLocalizedString("Loading...", comment: "Loading...")
            
            cell.dateTextLabel.text = ""
            
        // For some reason the compiler will crash with the .Cached case
        default:
            
            cell.userInteractionEnabled = true
            
            cell.messageTextLabel.text = message.text!
            
            cell.dateTextLabel.text = self.dateFormatter.stringFromValue(message.date!)
        }
    }
    
    // MARK: - UITableViewDataSource
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        
        assert(tableView == self.tableView, "Only one table view is supported")
        
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        assert(section == 0, "One a single section is supported")
        
        return self.searchResultsController.searchResults.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = self.tableView.dequeueReusableCellWithIdentifier(MessageCell.Identifier, forIndexPath: indexPath) as! MessageCell
        
        let index = indexPath.row
        
        self.configureCell(cell, atIndex: index, error: nil)
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        let data = self.searchResultsController.dataAtIndex(indexPath.row)
        
        switch data {
            
        case .NotCached(_): return
            
        default: break
        }
        
        let message = self.searchResultsController.searchResults[indexPath.row]
        
        let resourceIDAttributeName = self.searchResultsController.store.cacheStore.resourceIDAttributeName
        
        let resouceID = message.valueForKey(resourceIDAttributeName) as! String
        
        let resource = Resource(message.entity.name!, resouceID)
        
        // edit
        
        let alertController = UIAlertController(title: NSLocalizedString("Edit", comment: "Edit"),
            message: NSLocalizedString("Enter the text of the message", comment: "Enter the text of the message"),
            preferredStyle: UIAlertControllerStyle.Alert)
        
        alertController.addTextFieldWithConfigurationHandler { (textField: UITextField) -> Void in
            
            textField.text = message.text!
        }
        
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Edit", comment: "Edit"),
            style: UIAlertActionStyle.Default, handler: { (action: UIAlertAction) -> Void in
                
                let textField = alertController.textFields!.first!
                
                let text = textField.text!
                
                let values = [Message.Attribute.Text.rawValue: Value.Attribute(AttributeValue.String(text))]
                                
                NSOperationQueue().addOperationWithBlock({ () -> Void in
                    
                    do { try self.searchResultsController.store.edit(resource, changes: values) }
                        
                    catch {
                        
                        NSOperationQueue.mainQueue().addOperationWithBlock({ () in
                            
                            self.showErrorAlert("\(error)")
                        })
                        
                        return
                    }
                })
        }))
        
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"),
            style: UIAlertActionStyle.Destructive, handler: { (action: UIAlertAction) -> Void in
                
                alertController.dismissViewControllerAnimated(true, completion: nil)
        }))
        
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    override func tableView(tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
        
        return .Delete
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        
        // get model object
        let managedObject = self.searchResultsController.searchResults[indexPath.row]
        
        switch editingStyle {
            
        case .Delete:
            
            self.deleteManagedObject(managedObject)
            
        default:
            
            return
        }
    }
    
    // MARK: - Private Methods
    
    private func deleteManagedObject(managedObject: NSManagedObject) {
        
        let resourceIDAttributeName = self.searchResultsController.store.cacheStore.resourceIDAttributeName
        
        let resouceID = managedObject.valueForKey(resourceIDAttributeName) as! String
        
        let resource = Resource(managedObject.entity.name!, resouceID)
        
        self.requestQueue.addOperationWithBlock { () in
            
            do { try self.searchResultsController.store.delete(resource) }
            
            catch {
                
                NSOperationQueue.mainQueue().addOperationWithBlock({ () in
                    
                    self.showErrorAlert("\(error)", retryHandler: { () -> Void in
                        
                        self.deleteManagedObject(managedObject)
                    })
                })
            }
        }
    }
}

// MARK: - Supporting Classes

class MessageCell: UITableViewCell {
    
    static var Identifier: String { return "MessageCell" }
    
    @IBOutlet weak var messageTextLabel: UILabel!
    
    @IBOutlet weak var dateTextLabel: UILabel!
    
}

