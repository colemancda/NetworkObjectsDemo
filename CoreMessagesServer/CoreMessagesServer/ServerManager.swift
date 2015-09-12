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
import RoutingHTTPServer

public func StartServer(port: Int) {
    
    try! ServerManager.sharedManager.start(port)
}

public class ServerManager: ServerDataSource {
    
    public static let sharedManager = ServerManager()
    
    // MARK: - Properties
    
    public lazy var server: Server.HTTP = {
        
        let managedObjectModel = CoreMessages.ManagedObjectModel()
        
        let model = managedObjectModel.toModel("id")!
       
        let server = NetworkObjects.Server.HTTP(model: model, dataSource: self)
        
        return server
    }()
    
    public lazy var HTTPServer: RoutingHTTPServer = {
        
        let HTTPServer = RoutingHTTPServer()
        
        // instance handlers
        do {
            
            let instancePathExpression = "{^/([a-z]+)/(\\d+)}"
            
            let instanceBlock = { (routeRequest: RouteRequest!, routeResponse: RouteResponse!) -> Void in
                
                var request = Server.HTTP.Request()
                
                request.URI = routeRequest.url().relativeString!
                
                request.
            }
            
            HTTPServer.get(instancePathExpression, withBlock: instanceBlock)
            
            HTTPServer.put(instancePathExpression, withBlock: instanceBlock)
            
            HTTPServer.delete(instancePathExpression, withBlock: instanceBlock)
        }
        
        // create handler
        
        
        
        // search handler
        
        
        
    }()
    
    // MARK: - Initialization
    
    public init() { }
    
    // MARK: - Methods
    
    public func start(port: Int) throws {
        
        self.HTTPServer.setPort(UInt16(port))
        
        try self.HTTPServer.start()
    }
    
    public func stop() {
        
        self.HTTPServer.stop(false)
    }
    
    // MARK: - ServerDataSource
    
    public func server<T : ServerType>(server: T, storeForRequest request: RequestMessage) -> Store {
        
        
    }
}
