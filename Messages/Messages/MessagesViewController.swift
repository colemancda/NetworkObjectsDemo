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

class MessagesViewController: UITableViewController, SearchResultsTableViewController {
    
    // MARK: - Properties
    
    var client: NetworkObjects.Client.HTTP!
    
    var searchResultsController: SearchResultsController<MessagesViewController>!
    
    var serverURL: String! {
        
        didSet {
            
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
            
            self.searchResultsController = try! SearchResultsController(fetchRequest: fetchRequest, store: store, delegate: self)
        }
    }
    
    // MARK: - Private Properties
    
    private let dateFormatter = StyledDateFormatter(dateStyle: .ShortStyle, timeStyle: .ShortStyle)
    
    // MARK: - Initialization
    
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
    
    // MARK: - SearchResultsTableViewController
    
    func dequeueReusableCellForIndex(index: Int) -> MessageCell {
        
        let indexPath = NSIndexPath(forRow: index, inSection: 0)
        
        let cell = self.tableView.dequeueReusableCellWithIdentifier(MessageCell.Identifier, forIndexPath: indexPath) as! MessageCell
        
        return cell
    }
    
    func configureCell(cell: MessageCell, atIndex index: Int, withData data: SearchResultData<Message>, error: ErrorType?) {
        
        guard error == nil else {
            
            cell.userInteractionEnabled = false
            
            cell.messageTextLabel.text = NSLocalizedString("Error: ", comment: "Error: ") + "\(error!)"
            
            cell.dateTextLabel.text = ""
            
            return
        }
        
        switch data {
            
        case .NotCached(_):
            
            cell.userInteractionEnabled = false
            
            cell.messageTextLabel.text = NSLocalizedString("Loading...", comment: "Loading...")
            
            cell.dateTextLabel.text = ""
            
        case let .Cached(message):
            
            cell.userInteractionEnabled = true
            
            cell.messageTextLabel.text = message.text!
            
            cell.dateTextLabel.text = self.dateFormatter.stringFromValue(message.date!)
        }
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        // show edit controller
        
        
    }
}

// MARK: - Supporting Classes

class MessageCell: UITableViewCell {
    
    static var Identifier: String { return "MessageCell" }
    
    @IBOutlet weak var messageTextLabel: UILabel!
    
    @IBOutlet weak var dateTextLabel: UILabel!
    
}

