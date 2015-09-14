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
import CoreMessages

class MessagesViewController: UITableViewController {
    
    // MARK: - Properties
    
    var serverURL: String! {
        
        didSet {
            
            let managedObjectModel = CoreMessages.ManagedObjectModel()
            
            let model = managedObjectModel.toModel()!
            
            self.client = Client.HTTP(serverURL: serverURL, model: model, HTTPClient: HTTP.Client())
        }
    }
    
    private(set) var messages = [Resource]()
    
    private let requestQueue = NSOperationQueue()
    
    private var client: NetworkObjects.Client.HTTP!
    
    // MARK: - Initialization
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.refresh(self)
    }
    
    // MARK: - Actions
    
    @IBAction func refresh(sender: AnyObject) {
        
        let fetchRequest = FetchRequest(entityName: "Message", sortDescriptors: [])
        
        self.requestQueue.addOperationWithBlock { () -> Void in
            
            var results: [Resource]!
            
            do { results = try self.client.search(fetchRequest) }
            
            catch {
                
                NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                    
                    // show error
                })
                
                return
            }
            
            NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                
                self.messages = results
                
                self.tableView.reloadData()
            })
        }
    }
    
    // MARK: - UITableViewDataSource
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return self.messages.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCellWithIdentifier("MessageCell", forIndexPath: indexPath) as! MessageCell
        
        let message = self.messages[indexPath.row]
        
        // fetch values from server
        
        
    }
}

// MARK: - Supporting Classes

class MessageCell: UITableViewCell {
    
    @IBOutlet weak var messageTextLabel: UILabel!
    
    @IBOutlet weak var dateTextLabel: UILabel!
    
}

