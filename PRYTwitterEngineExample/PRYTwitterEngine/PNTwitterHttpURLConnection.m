//
//  PRYTwitterHttpURLConnection.m
//  PRYTwitterEngineExample
//
//  Created by iosdev on 2/28/13.
//  Copyright (c) 2013 iosdev. All rights reserved.
//

#import "PNTwitterHttpURLConnection.h"

@interface NSString (UUID)
+ (NSString*)stringWithNewUUID;
@end


@implementation NSString (UUID)
+ (NSString*)stringWithNewUUID
{
    // Create a new UUID
    CFUUIDRef uuidObj = CFUUIDCreate(nil);
    
    // Get the string representation of the UUID
    NSString *newUUID = (NSString*)CFUUIDCreateString(nil, uuidObj);
    CFRelease(uuidObj);
    return [newUUID autorelease];
}
@end

@implementation PNTwitterHttpURLConnection

- (id)initWithRequest:(NSURLRequest *)request delegate:(id < NSURLConnectionDelegate >)delegate {
    self = [super initWithRequest:request delegate:delegate];
    if (self) {
        _data = [[NSMutableData alloc] initWithCapacity:0];
        _identifier = [[NSString stringWithNewUUID] retain];
        _URL = [[request URL] retain];
    }
    
    return self;
}


- (void) dealloc{
    [_response release];
    [_data release];
    [_identifier release];
	[_URL release];
    
    [super dealloc];
}

#pragma mark Data helper methods


- (void)resetDataLength
{
    [_data setLength:0];
}


- (void)appendData:(NSData *)data
{
    [_data appendData:data];
}


#pragma mark Accessors


- (NSString *)identifier
{
    return _identifier;
}


- (NSData *)data
{
    return _data;
}


- (NSURL *)URL
{
    return _URL;
}

@end
