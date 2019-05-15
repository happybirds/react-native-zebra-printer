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
                printer[@"type"] = @"Bluetooth";
                printer[@"address"] = accessory.serialNumber;
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

        if([printer valueForKey:@"type"] == @"Bluetooth") {
            id<ZebraPrinterConnection, NSObject> thePrinterConn = [[MfiBtPrinterConnection alloc] initWithSerialNumber:[printer valueForKey:@"address"]];
            [((MfiBtPrinterConnection*)thePrinterConn) setTimeToWaitAfterWriteInMilliseconds:30];
            BOOL success = [thePrinterConn open];

            if(success == YES){
                NSString *printLabel;
                printLabel = [NSString stringWithFormat: @"! %@", command];
                NSError *error = nil;
                success = success && [thePrinterConn write:[printLabel dataUsingEncoding:NSUTF8StringEncoding] error:&error];

                NSLog(@"IOS >> Sending Data");

                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success != YES || error != nil) {
                        NSLog(@"IOS >> Failed to send");
                        UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
                        [errorAlert show];
                    }
                });
                [thePrinterConn close];
                resolve((id)kCFBooleanTrue);
            } else {
                NSLog(@"IOS >> Failed to connect");
                resolve((id)kCFBooleanFalse);
            }
        }
    });
}


RCT_EXPORT_METHOD(checkPrinterStatus: (NSString *)serialCode
                            resolver: (RCTPromiseResolveBlock)resolve
                            rejector: (RCTPromiseRejectBlock)reject) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^ {
        id<ZebraPrinterConnection, NSObject> connection = [[MfiBtPrinterConnection alloc] initWithSerialNumber:serialCode];
        [((MfiBtPrinterConnection*)connection) setTimeToWaitAfterWriteInMilliseconds:80];
        BOOL success = [connection open];
        if (success) {
            NSError *error = nil;
            [SGD SET:@"device.languages" withValue:@"zpl" andWithPrinterConnection:connection error:&error];
            [SGD SET:@"ezpl.media_type" withValue:@"continuous" andWithPrinterConnection:connection error:&error];
            [SGD SET:@"zpl.label_length" withValue:@"100" andWithPrinterConnection:connection error:&error];
            if (error) {
                NSLog(@"asssddd %@", error.localizedDescription);
                resolve((id)kCFBooleanFalse);
                return;
            }
        }
        if (success) {
            NSError *error = nil;
            id<ZebraPrinter, NSObject> printer = [ZebraPrinterFactory getInstance:connection error:&error];
            if (error) {
                NSLog(@"%@", error.localizedDescription);
                [connection close];
                resolve((id)kCFBooleanFalse);
                return;
            }

            PrinterStatus *status = [printer getCurrentStatus:&error];
            if (error) {
                NSLog(@"wtf %@", error.localizedDescription);
                [connection close];
                resolve((id)kCFBooleanFalse);
                return;
            }

            NSLog(@"Is printer ready to print: %d", (int)status.isReadyToPrint);
            [connection close];
            resolve(status.isReadyToPrint ? (id)kCFBooleanTrue : (id)kCFBooleanFalse);
        } else {
            [connection close];
            resolve((id)kCFBooleanFalse);
            NSLog(@"Failed to connect to printer");
        }
    });
}

@end
