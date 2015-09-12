//
//  File.swift
//  CoreMessagesServer
//
//  Created by Alsey Coleman Miller on 9/12/15.
//  Copyright © 2015 ColemanCDA. All rights reserved.
//

import Foundation

public let ServerApplicationSupportFolderURL: NSURL = try! NSFileManager.defaultManager().URLForDirectory(.ApplicationSupportDirectory, inDomain: NSSearchPathDomainMask.LocalDomainMask, appropriateForURL: nil, create: false).URLByAppendingPathComponent("MessagesServer")

public let ServerSQLiteFileURL = ServerApplicationSupportFolderURL.URLByAppendingPathComponent("data.sqlite")