//
//  Message.swift
//  CoreMessages
//
//  Created by Alsey Coleman Miller on 9/14/15.
//  Copyright © 2015 ColemanCDA. All rights reserved.
//

import SwiftFoundation
import CoreData

public class Message: NSManagedObject {
    
    public enum Attribute: String {
        
        case Date = "date"
        case Text = "text"
    }
    
    public static var EntityName: String { return "Message" }
    
    public var text: String? {
        
        let key = Attribute.Text.rawValue
        
        self.willAccessValueForKey(key)
        let value = self.primitiveValueForKey(key) as? String
        self.didAccessValueForKey(key)
        
        return value
    }
    
    public var date: Date? {
        
        let key = Attribute.Date.rawValue
        
        self.willAccessValueForKey(key)
        let value = self.primitiveValueForKey(key) as? NSDate
        self.didAccessValueForKey(key)
        
        if let dateValue = value { return Date(foundation: dateValue) } else { return nil }
    }
}
