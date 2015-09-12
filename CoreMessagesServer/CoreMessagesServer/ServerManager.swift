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
        
        let handler = { (routeRequest: RouteRequest!, routeResponse: RouteResponse!) -> Void in
            
            // create request
            var httpRequest = Server.HTTP.Request()
            
            httpRequest.headers = routeRequest.headers as! [String: String]
            
            httpRequest.URI = routeRequest.url().relativeString!
            
            httpRequest.method = SwiftFoundation.HTTP.Method(rawValue: routeRequest.method())!
            
            // add body
            if let jsonString = NSString(data: routeRequest.body(), encoding: NSUTF8StringEncoding),
                let jsonValue = JSON.Value(string: jsonString as String),
                let jsonObject = jsonValue.objectValue {
                
                httpRequest.body = jsonObject
            }
            
            // process request
            let httpResponse = self.server.input(httpRequest)
            
            
        }
        
        // add handlers
        
        let instancePathExpression = "{^/([a-z]+)/(\\d+)}"
        
        HTTPServer.get(instancePathExpression, withBlock: handler)
        
        HTTPServer.put(instancePathExpression, withBlock: handler)
        
        HTTPServer.delete(instancePathExpression, withBlock: handler)
        
        // create handler
        
        HTTPServer.post("{^/([a-z]+)}", withBlock: handler)
        
        // search handler
        
        HTTPServer.post("{^/search/([a-z]+)}", withBlock: handler)
        
        // function handler
        
        HTTPServer.post("{^/([a-z]+)/(\\d+)}", withBlock: handler)
        
        return HTTPServer
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
