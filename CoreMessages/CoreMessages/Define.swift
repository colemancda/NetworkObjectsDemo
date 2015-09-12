//
//  Define.swift
//  CoreMessages
//
//  Created by Alsey Coleman Miller on 9/12/15.
//  Copyright © 2015 ColemanCDA. All rights reserved.
//

import SwiftFoundation
import CoreData

/// The managed object model for the CoreMessages framework.
public func ManagedObjectModel() -> NSManagedObjectModel {
    
    return NSManagedObjectModel(contentsOfURL: NSBundle(identifier: CoreMessages.BundleIdentifier)!.URLForResource("Model", withExtension: "momd")!)!
}

// MARK: - Internal

/// The bundle identifier of CoreMessages.
public let BundleIdentifier = "com.colemancda.CoreMessages"

public let ResourceIDAttributeName = "id"
