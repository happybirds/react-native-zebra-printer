//
//  RCTZebraBTPrinter.m
//  RCTZebraBTPrinter
//
//  Created by Jakub Martyčák on 17.04.16.
//  Copyright © 2016 Jakub Martyčák. All rights reserved.
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
#import <SGD.h>

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
    portDiscovery: (NSString *)type
    resolve: (RCTPromiseResolveBlock)resolve){

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^ {
        NSMutableArray *printers = [[NSMutableArray alloc] init];
        
        EAAccessoryManager *sam = [EAAccessoryManager sharedAccessoryManager];
        NSArray *connectedAccessories = [sam connectedAccessories];
        for (EAAccessory *accessory in connectedAccessories) {
            if([accessory.protocolStrings indexOfObject:@"com.zebra.rawport"] != NSNotFound){
                NSMutableDictionary *printer = [[NSMutableDictionary alloc] init];
                printer[@"type"] = @"BT";
                printer[@"address"] = accessory.serialNumber;
                [printers addObject: printer];
            }
        }

        NSError *error = nil;
        NSArray *networkPrinters = [NetworkDiscoverer localBroadcast:&error];
        if (error == nil) {
            for (DiscoveredPrinterNetwork *networkPrinter in networkPrinters) {
                NSMutableDictionary *printer = [[NSMutableDictionary alloc] init];
                printer[@"type"] = @"TCP";
                printer[@"address"] = networkPrinter.address;
                printer[@"port"] = [NSNumber numberWithLong:networkPrinter.port];
                [printers addObject: printer];
            }
        }

        resolve((id)printers);
    });
}

RCT_EXPORT_METHOD(
    printLabel: (NSDictionary *)printer
    userCommand:(NSString *)command
    resolve: (RCTPromiseResolveBlock)resolve
    rejector:(RCTPromiseRejectBlock)reject){

    NSLog(@"IOS >> printLabel triggered");

    NSLog(@"IOS >> Connecting");

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^ {

        id<ZebraPrinterConnection, NSObject> thePrinterConn = nil;
        if([printer valueForKey:@"type"] == @"BT") {
            thePrinterConn = [[MfiBtPrinterConnection alloc] initWithSerialNumber:[printer valueForKey:@"address"]];
            [((MfiBtPrinterConnection*)thePrinterConn) setTimeToWaitAfterWriteInMilliseconds:30];
        }
        else if ([printer valueForKey:@"type"] == @"TCP") {
            thePrinterConn = [[TcpPrinterConnection alloc] initWithAddress:[printer valueForKey:@"address"] 
                                                               andWithPort:(NSInteger)[printer valueForKey:@"port"]];
        }

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
