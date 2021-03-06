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
import CoreData

/// Objective-C wrapper for ```ServerManager```
@objc public class MessagesServer: NSObject {
    
    public static func start() {
        
        let port = 8080
        
        NSLog("Starting server on port: \(port)")
        
        try! ServerManager.sharedManager.start(port)
    }
}

public final class ServerManager: ServerDataSource, ServerDelegate {
    
    public static let sharedManager = ServerManager()
    
    // MARK: - Properties
    
    public lazy var server: Server.HTTP = {
        
        let managedObjectModel = CoreMessages.ManagedObjectModel()
        
        let model = managedObjectModel.toModel()!
       
        let server = NetworkObjects.Server.HTTP(model: model, dataSource: self, delegate: self)
        
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
            
            routeResponse.statusCode = httpResponse.statusCode
            
            for (header, value) in httpResponse.headers {
                
                routeResponse.setHeader(header, value: value)
            }
            
            if httpResponse.body.count > 0 {
                
                routeResponse.respondWithData(NSData(bytes: httpResponse.body))
            }
        }
        
        // add handlers
        
        let instancePathExpression = "/:entity/:id"
        
        HTTPServer.get(instancePathExpression, withBlock: handler)
        
        HTTPServer.put(instancePathExpression, withBlock: handler)
        
        HTTPServer.delete(instancePathExpression, withBlock: handler)
        
        // create handler
        
        HTTPServer.post("/:entity", withBlock: handler)
        
        // search handler
        
        HTTPServer.post("/search/:entity", withBlock: handler)
        
        // function handler
        
        HTTPServer.post("/:entity/:id/:function", withBlock: handler)
        
        return HTTPServer
    }()
    
    public lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        
        let managedObjectModel = CoreMessages.ManagedObjectModel()
        
        // add resource ID attribute
        managedObjectModel.addResourceIDAttribute(CoreMessages.ResourceIDAttributeName)
        
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        
        try! persistentStoreCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: ServerSQLiteFileURL, options: nil)
        
        return persistentStoreCoordinator
        
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
    
    public func server<T : ServerType>(server: T, storeForRequest request: RequestMessage) -> CoreModel.Store {
        
        // create a new managed object context
        let managedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        
        managedObjectContext.undoManager = nil
        
        // setup persistent store coordinator
        managedObjectContext.persistentStoreCoordinator = self.persistentStoreCoordinator
        
        guard let store = CoreDataStore(model: self.server.model, managedObjectContext: managedObjectContext, resourceIDAttributeName: CoreMessages.ResourceIDAttributeName) else {
            
            fatalError("Could not create Store for request: \(request)")
        }
        
        return store
    }
    
    // MARK: - ServerDelegate
    
    public func server<T : ServerType>(server: T, willCreateResource resource: Resource, var initialValues: ValuesObject, context: Server.RequestContext) -> ValuesObject {
        
        switch resource.entityName {
            
        case Message.EntityName:
            
            // set creation date on server
            
            let date = Date()
            
            let value = Value.Attribute(.Date(date))
            
            initialValues[Message.Attribute.Date.rawValue] = value
            
        default: break
        }
        
        return initialValues
    }
    
    public func server<T : ServerType>(server: T, didEncounterInternalError error: ErrorType, context: Server.RequestContext) {
        
        print("Internal Server Error: \(error)")
    }
}
