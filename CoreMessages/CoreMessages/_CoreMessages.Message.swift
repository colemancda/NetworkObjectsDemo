// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to CoreMessages.Message.swift instead.

import CoreData

public enum CoreMessages.MessageAttributes: String {
    case date = "date"
    case text = "text"
}

@objc public
class _CoreMessages.Message: NSManagedObject {

    // MARK: - Class methods

    public class func entityName () -> String {
        return "Message"
    }

    public class func entity(managedObjectContext: NSManagedObjectContext!) -> NSEntityDescription! {
        return NSEntityDescription.entityForName(self.entityName(), inManagedObjectContext: managedObjectContext);
    }

    // MARK: - Life cycle methods

    public override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext!) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }

    public convenience init(managedObjectContext: NSManagedObjectContext!) {
        let entity = _CoreMessages.Message.entity(managedObjectContext)
        self.init(entity: entity, insertIntoManagedObjectContext: managedObjectContext)
    }

    // MARK: - Properties

    public var date: NSDate?
    {
        self.willAccessValueForKey(CoreMessages.MessageAttributes.date.rawValue)
        let date = self.primitiveValueForKey(CoreMessages.MessageAttributes.date.rawValue) as? NSDate
        self.didAccessValueForKey(CoreMessages.MessageAttributes.date.rawValue)
        return date
    }

    // func validateDate(value: AutoreleasingUnsafeMutablePointer<AnyObject>, error: NSErrorPointer) -> Bool {}

    public var text: String?
    {
        self.willAccessValueForKey(CoreMessages.MessageAttributes.text.rawValue)
        let text = self.primitiveValueForKey(CoreMessages.MessageAttributes.text.rawValue) as? String
        self.didAccessValueForKey(CoreMessages.MessageAttributes.text.rawValue)
        return text
    }

    // func validateText(value: AutoreleasingUnsafeMutablePointer<AnyObject>, error: NSErrorPointer) -> Bool {}

    // MARK: - Relationships

}

