//
//  RCTZebraBTPrinter.m
//  RCTZebraBTPrinter
//
//  Created by Yao on 2020-02-18.
//  Copyright © 2020 timeless. All rights reserved.
//

#import "RCTZebraBTPrinter.h"
#import <ExternalAccessory/ExternalAccessory.h>

//ZEBRA
#import "ZebraPrinterConnection.h"
#import "ZebraPrinter.h"
#import "ZebraPrinterFactory.h"
#import "MfiBtPrinterConnection.h"
#import "TcpPrinterConnection.h"
#import "NetworkDiscoverer.h"
#import "DiscoveredPrinterNetwork.h"
#import "SGD.h"

@interface RCTZebraBTPrinter ()
@end


@implementation RCTZebraBTPrinter

RCT_EXPORT_MODULE();

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

#pragma mark - Methods available form Javascript

RCT_EXPORT_METHOD(
    printLabel: (NSString *)address
    userPort:(NSInteger)userPort
    userCommand:(NSString *)command
    resolve: (RCTPromiseResolveBlock)resolve
    rejector:(RCTPromiseRejectBlock)reject){

    NSLog(@"IOS >> printLabel triggered");

    NSLog(@"IOS >> Connecting");

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^ {
        id<ZebraPrinterConnection, NSObject> thePrinterConn = nil;
        thePrinterConn = [[TcpPrinterConnection alloc] initWithAddress:address andWithPort:userPort] ;
        BOOL success = [thePrinterConn open];

        if(success == YES){
            NSError *error = nil;
            success = [thePrinterConn write:[command dataUsingEncoding:NSUTF8StringEncoding] error:&error];
            NSLog(@"IOS >> Sending Data");
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success != YES || error != nil) {
                    NSLog(@"IOS >> Failed to send");
                    NSLog([error localizedDescription]);
                }
            });
            [thePrinterConn close];
            resolve((id)kCFBooleanTrue);
        } else {
            NSLog(@"IOS >> Failed to connect");
            resolve((id)kCFBooleanFalse);
        }
    });
}

@end
