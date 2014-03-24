//
//  PRYTwitterHttpURLConnection.h
//  PRYTwitterEngineExample
//
//  Created by iosdev on 2/28/13.
//  Copyright (c) 2013 iosdev. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PNTwitterHttpURLConnection : NSURLConnection {
    NSMutableData *_data;                   // accumulated data received on this connection
    NSString *_identifier;
	NSURL *_URL;							// the URL used for the connection (needed as a base URL when parsing with libxml)
    NSHTTPURLResponse * _response;          // the response.
}

// Data helper methods
- (void)resetDataLength;
- (void)appendData:(NSData *)data;

// Accessors
- (NSString *)identifier;
- (NSData *)data;
- (NSURL *)URL;

@property (nonatomic, retain) NSHTTPURLResponse *response;
@end
