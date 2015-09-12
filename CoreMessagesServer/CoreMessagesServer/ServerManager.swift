//
//  ServerManager.swift
//  CoreMessagesServer
//
//  Created by Alsey Coleman Miller on 9/12/15.
//  Copyright © 2015 ColemanCDA. All rights reserved.
//

import SwiftFoundation
import CoreModel
import NetworkObjects
import CoreMessages

public class ServerManager: ServerDataSource {
    
    public lazy var server: Server.HTTP = {
        
        let model = CoreMessages.ManagedObjectModel()
       
        let server = NetworkObjects.Server.HTTP(model: model, dataSource: self)
        
    }()
}
