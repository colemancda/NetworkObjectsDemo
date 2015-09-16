//
//  File.swift
//  CoreMessagesServer
//
//  Created by Alsey Coleman Miller on 9/12/15.
//  Copyright © 2015 ColemanCDA. All rights reserved.
//

import Foundation

public let ServerApplicationSupportFolderURL: NSURL = {
    
    let folderURL = try! NSFileManager.defaultManager().URLForDirectory(.ApplicationSupportDirectory, inDomain: NSSearchPathDomainMask.LocalDomainMask, appropriateForURL: nil, create: false).URLByAppendingPathComponent("MessagesServer")
    
    let fileExists = NSFileManager.defaultManager().fileExistsAtPath(folderURL.path!, isDirectory: nil)
    
    if fileExists == false {
        
        // create directory
        try! NSFileManager.defaultManager().createDirectoryAtURL(folderURL, withIntermediateDirectories: true, attributes: nil)
    }
    
    return folderURL
}()

public let ServerSQLiteFileURL = ServerApplicationSupportFolderURL.URLByAppendingPathComponent("data.sqlite")