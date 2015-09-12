//
//  main.m
//  MessagesServerDaemon
//
//  Created by Alsey Coleman Miller on 9/6/15.
//  Copyright © 2015 ColemanCDA. All rights reserved.
//

#import <Foundation/Foundation.h>
@import CoreMessagesServer

int main(int argc, const char * argv[]) {
    
    @autoreleasepool {
        
        start
    }
    
    [[NSRunLoop currentRunLoop] run];
    
    return 0;
}
