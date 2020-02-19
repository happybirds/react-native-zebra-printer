//
//  RCTZebraBTPrinter.h
//  RCTZebraBTPrinter
//
//  Created by Jakub Martyčák on 17.04.16.
//  Copyright © 2016 Jakub Martyčák. All rights reserved.
//

#import <RCTBridgeModule.h>
#import <RCTEventDispatcher.h>

@interface RCTZebraBTPrinter : NSObject <RCTBridgeModule> {
	
	RCTPromiseResolveBlock _connectionResolver;
    RCTPromiseRejectBlock _connectionRejector;

}

@end
