//
//  ViewController.swift
//  Messages
//
//  Created by Alsey Coleman Miller on 9/6/15.
//  Copyright © 2015 ColemanCDA. All rights reserved.
//

import UIKit

class LoginViewController: UIViewController {

    // MARK: - IB Outlets
    
    @IBOutlet weak var serverURLTextField: UITextField!
    
    // MARK: - Initialization
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        
    }
    
    // MARK: - Segue
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        switch segue.identifier! {
            
        case "Login":
            
            let destinationVC = segue.destinationViewController as! MessagesViewController
            
            destinationVC.serverURL = self.serverURLTextField.text
            
        default: break
        }
    }
}

