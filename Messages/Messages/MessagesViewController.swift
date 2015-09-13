//
//  MessagesViewController.swift
//  Messages
//
//  Created by Alsey Coleman Miller on 9/13/15.
//  Copyright © 2015 ColemanCDA. All rights reserved.
//

import UIKit
import Foundation
import NetworkObjects
import CoreModel

class MessagesViewController: UITableViewController {
    
    // MARK: - Properties
    
    var client: NetworkObjects.Client!
    
    private(set) var messages = [Resource]()
    
    private let requestQueue = NSOperationQueue()
    
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
            
            do { self.messages = try self.client.search(fetchRequest) }
            
            catch {
                
                NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                    
                    // show error
                })
                
                return
            }
            
            
        }
    }
}