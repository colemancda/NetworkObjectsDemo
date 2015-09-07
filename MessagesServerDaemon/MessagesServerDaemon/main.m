//
//  main.m
//  MessagesServerDaemon
//
//  Created by Alsey Coleman Miller on 9/6/15.
//  Copyright © 2015 ColemanCDA. All rights reserved.
//

#import <Foundation/Foundation.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        int i;
        
        // Disable output buffering.
        setbuf(stdout, NULL);
        
        for (i = 1; i <= 10; i++) {
            printf("%d\n", i);
            usleep(500000);
        }
        
        // insert code here...
        NSLog(@"Hello, World!");
    }
    return 0;
}
